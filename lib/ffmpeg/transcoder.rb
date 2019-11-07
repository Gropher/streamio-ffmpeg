require 'open3'
require 'shellwords'

module FFMPEG
  class Transcoder
    @@timeout = 30

    def self.timeout=(time)
      @@timeout = time
    end

    def self.timeout
      @@timeout
    end

    def initialize(movie, output_file, options = EncodingOptions.new, transcoder_options = {}, global_options = {})
      @movie = movie
      @output_file = output_file

      if options.is_a?(String)
        @raw_options = "-i #{Shellwords.escape(@movie.path)} " + options
      elsif options.is_a?(EncodingOptions)
        @raw_options = options
      elsif options.is_a?(Hash)
        @raw_options = EncodingOptions.new(options.merge(:input => @movie.path))
      else
        raise ArgumentError, "Unknown options format '#{options.class}', should be either EncodingOptions, Hash or String."
      end

      @transcoder_options = transcoder_options

      if global_options.is_a?(String)
        @global_options = global_options
      elsif global_options.is_a?(EncodingOptions)
        @global_options = global_options
      elsif global_options.is_a?(Hash)
        @global_options = EncodingOptions.new(global_options)
      else
        raise ArgumentError, "Unknown global options format '#{global_options.class}', should be either EncodingOptions, Hash or String."
      end
      @errors = []

      apply_transcoder_options
    end

    def run(&block)
      transcode_movie(&block)
      if @transcoder_options[:validate]
        validate_output_file(&block)
        return encoded
      else
        return nil
      end
    end

    def encoding_succeeded?
      @errors << "no output file created" and return false unless File.exists?(@output_file)
      @errors << "encoded file is invalid" and return false unless encoded.valid?
      true
    end

    def encoded
      @encoded ||= Movie.new(@output_file)
    end

    def transcode_command
      "#{FFMPEG.ffmpeg_binary} #{@global_options} -y #{@raw_options} #{Shellwords.escape(@output_file)}"
    end

    private
    # frame= 4855 fps= 46 q=31.0 size=   45306kB time=00:02:42.28 bitrate=2287.0kbits/
    def transcode_movie
      @command = transcode_command
      FFMPEG.logger.info("Running transcoding...\n#{@command}\n")
      @output = ""

      Open3.popen3(@command) do |stdin, stdout, stderr, wait_thr|
        begin
          yield(0.0) if block_given?
          next_line = Proc.new do |line|
            fix_encoding(line)
            @output << line
            if line.include?("time=")
              if line =~ /time=(\d+):(\d+):(\d+.\d+)/ # ffmpeg 0.8 and above style
                time = ($1.to_i * 3600) + ($2.to_i * 60) + $3.to_f
              else # better make sure it wont blow up in case of unexpected output
                time = 0.0
              end
              progress = time / @movie.duration
              yield(progress) if block_given?
            end
          end

          if @@timeout
            stderr.each_with_timeout(wait_thr.pid, @@timeout, 'size=', &next_line)
          else
            stderr.each('size=', &next_line)
          end

        rescue Timeout::Error => e
          FFMPEG.logger.error "Process hung...\n@command\n#{@command}\nOutput\n#{@output}\n"
          raise Error, "Process hung. Full output: #{trunkated_output}"
        end
      end
    end

    def validate_output_file(&block)
      if encoding_succeeded?
        yield(1.0) if block_given?
        FFMPEG.logger.info "Transcoding of #{@movie.path} to #{@output_file} succeeded\n"
      else
        errors = "Errors: #{@errors.join(", ")}. "
        FFMPEG.logger.error "Failed encoding...\n#{@command}\n\n#{@output}\n#{errors}\n"
        raise Error, "Failed encoding.#{errors}Full output: #{trunkated_output}"
      end
    end

    def trunkated_output
      @output.to_s.chars.last(10240).join
    end

    def apply_transcoder_options
       # if true runs #validate_output_file
      @transcoder_options[:validate] = @transcoder_options.fetch(:validate) { true }

      return if @movie.calculated_aspect_ratio.nil?
      case @transcoder_options[:preserve_aspect_ratio].to_s
      when "width"
        new_height = @raw_options.width / @movie.calculated_aspect_ratio
        new_height = new_height.ceil.even? ? new_height.ceil : new_height.floor
        new_height += 1 if new_height.odd? # needed if new_height ended up with no decimals in the first place
        @raw_options[:resolution] = "#{@raw_options.width}x#{new_height}"
      when "height"
        new_width = @raw_options.height * @movie.calculated_aspect_ratio
        new_width = new_width.ceil.even? ? new_width.ceil : new_width.floor
        new_width += 1 if new_width.odd?
        @raw_options[:resolution] = "#{new_width}x#{@raw_options.height}"
      when "crop"
        mw, mh = @movie.width.to_i, @movie.height.to_i
        ow, oh = @raw_options.width.to_i, @raw_options.height.to_i
        target_aspect_ratio = ow.to_f / oh.to_f

        FFMPEG.logger.info "After rotating: Calculated aspect: #{@movie.calculated_aspect_ratio} Dimensions before cropping: #{mw} x #{mh}\n"
        
        @raw_options[:filter] = "scale=(iw*sar)*max(#{ow}/(iw*sar)\\,#{oh}/ih):ih*max(#{ow}/(iw*sar)\\,#{oh}/ih), crop=#{ow}:#{oh}"

      when "fit"
        mw, mh = @movie.width.to_i, @movie.height.to_i
        ow, oh = @raw_options.width.to_i, @raw_options.height.to_i
        target_aspect_ratio = ow.to_f / oh.to_f

        FFMPEG.logger.info "After rotating: Calculated aspect: #{@movie.calculated_aspect_ratio} Dimensions before cropping: #{mw} x #{mh}\n"
        
        @raw_options[:filter] = "scale=(iw*sar)*min(#{ow}/(iw*sar)\\,#{oh}/ih):ih*min(#{ow}/(iw*sar)\\,#{oh}/ih), pad=#{ow}:#{oh}:(#{ow}-iw*min(#{ow}/iw\\,#{oh}/ih))/2:(#{oh}-ih*min(#{ow}/iw\\,#{oh}/ih))/2"

      when "auto"

        # Vertical videos will fit
        # Horizontal will crop

        mw, mh = @movie.width.to_i, @movie.height.to_i
        ow, oh = @raw_options.width.to_i, @raw_options.height.to_i
        target_aspect_ratio = ow.to_f / oh.to_f

        FFMPEG.logger.info "After rotating dimensions: #{mw} x #{mh}\n"

        if (mw < mh)

          FFMPEG.logger.info "Doing FIT thumbnailing\n"

          @raw_options[:filter] = "scale=(iw*sar)*min(#{ow}/(iw*sar)\\,#{oh}/ih):ih*min(#{ow}/(iw*sar)\\,#{oh}/ih), pad=#{ow}:#{oh}:(#{ow}-iw*min(#{ow}/iw\\,#{oh}/ih))/2:(#{oh}-ih*min(#{ow}/iw\\,#{oh}/ih))/2"
        else
          FFMPEG.logger.info "Doing FILL thumbnailing\n"

          @raw_options[:filter] = "scale=(iw*sar)*max(#{ow}/(iw*sar)\\,#{oh}/ih):ih*max(#{ow}/(iw*sar)\\,#{oh}/ih), crop=#{ow}:#{oh}"
        end
      end

    end

    def fix_encoding(output)
      output[/test/]
    rescue ArgumentError
      output.force_encoding("ISO-8859-1")
    end
  end
end

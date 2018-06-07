require 'spec_helper.rb'

module FFMPEG
  describe Movie do
    describe "initializing" do

      context "given a correct file" do
        before(:all) do
          @movie = Movie.new("#{fixture_path}/movies/awesome movie.mov")
        end

        it "should return valid cropdetect" do
          @movie.cropdetect.should == {:width=>384, :height=>376, :cropx=>256, :cropy=>102}
        end
      end
    end
  end
end

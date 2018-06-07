# -*- encoding: utf-8 -*-
# stub: streamio-ffmpeg 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "streamio-ffmpeg"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["David Backeus"]
  s.date = "2017-09-14"
  s.email = ["david@streamio.com"]
  s.files = ["CHANGELOG", "LICENSE", "README.md", "lib/ffmpeg", "lib/ffmpeg/encoding_options.rb", "lib/ffmpeg/errors.rb", "lib/ffmpeg/io_monkey.rb", "lib/ffmpeg/movie.rb", "lib/ffmpeg/transcoder.rb", "lib/ffmpeg/version.rb", "lib/streamio-ffmpeg.rb"]
  s.homepage = "http://github.com/streamio/streamio-ffmpeg"
  s.rubygems_version = "2.5.1"
  s.summary = "Wraps ffmpeg to read metadata and transcodes videos."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["~> 2.14"])
      s.add_development_dependency(%q<rake>, ["~> 10.1"])
    else
      s.add_dependency(%q<rspec>, ["~> 2.14"])
      s.add_dependency(%q<rake>, ["~> 10.1"])
    end
  else
    s.add_dependency(%q<rspec>, ["~> 2.14"])
    s.add_dependency(%q<rake>, ["~> 10.1"])
  end
end

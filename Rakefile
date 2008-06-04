require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'spec/rake/spectask'

PLUGIN = "even_better_nested_set"
NAME = "even_better_nested_set"
GEM_VERSION = "0.1"
AUTHOR = "Jonas Nicklas"
EMAIL = "jonas.nicklas@gmail.com"
HOMEPAGE = "http://merb-plugins.rubyforge.org/gibberish_attributes/"
SUMMARY = "A cool acts_as_nested_set alternative"

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", 'TODO']
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.require_path = 'lib'
  s.autorequire = PLUGIN
  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob("{lib,spec}/**/*")

  # toggle to test command line interface
  if true
    s.bindir = "bin"
    s.executables = %w( templater )
  end
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the plugin locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{NAME}-#{VERSION} --no-update-sources}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

namespace :jruby do

  desc "Run :package and install the resulting .gem with jruby"
  task :install => :package do
    sh %{#{SUDO} jruby -S gem install pkg/#{NAME}-#{Merb::VERSION}.gem --no-rdoc --no-ri}
  end
  
end

file_list = FileList['spec/*_spec.rb']

namespace :spec do
  desc "Run all examples with RCov"
  Spec::Rake::SpecTask.new('rcov') do |t|
    t.spec_files = file_list
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec']
  end
  
  desc "Generate an html report"
  Spec::Rake::SpecTask.new('report') do |t|
    t.spec_files = file_list
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec']
    t.spec_opts = ["--format", "html:doc/reports/specs.html"]
    t.fail_on_error = false
  end
  
  desc "heckle all"
  task :heckle => [ 'spec:heckle:uploaded_file', 'spec:heckle:sanitized_file' ]
  
  namespace :heckle do
    desc "Heckle UploadedFile"
    Spec::Rake::SpecTask.new('uploaded_file') do |t|
      t.spec_files = [ File.join(File.dirname(__FILE__), *%w[spec uploaded_file_spec.rb]) ]
      t.spec_opts = ["--heckle", "UploadColumn::UploadedFile"]
    end
    
    desc "Heckle SanitizedFile"
    Spec::Rake::SpecTask.new('sanitized_file') do |t|
      t.spec_files = [ File.join(File.dirname(__FILE__), *%w[spec uploaded_file_spec.rb]) ]
      t.spec_opts = ["--heckle", "UploadColumn::SanitizedFile"]
    end
  end

end


desc 'Default: run unit tests.'
task :default => 'spec:rcov'
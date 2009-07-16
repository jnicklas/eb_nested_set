require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'spec/rake/spectask'
require 'yard'

GEM = "eb_nested_set"
GEM_VERSION = "0.3.7"
AUTHOR = "Jonas Nicklas"
EMAIL = "jonas.nicklas@gmail.com"
HOMEPAGE = "http://github.com/jnicklas/eb_nested_set/tree/master"
SUMMARY = "A cool acts_as_nested_set alternative"

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.require_path = 'lib'
  s.autorequire = GEM
  s.files = %w(LICENSE README.md Rakefile init.rb) + Dir.glob("{lib,spec}/**/*")
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ["README.md", "LICENSE", "TODO", 'lib/**/*.rb']
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the plugin locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION} --no-update-sources}
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
    sh %{#{SUDO} jruby -S gem install pkg/#{GEM}-#{GEM_VERSION}.gem --no-rdoc --no-ri}
  end
  
end

spec_files = FileList['spec/*_spec.rb']

desc 'Default: run unit tests.'
task :default => 'spec'

task :specs => :spec
desc "Run all examples"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ['--color']
  t.spec_files = spec_files
end

namespace :spec do
  desc "Run all examples with RCov"
  Spec::Rake::SpecTask.new('rcov') do |t|
    t.spec_files = spec_files
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec,rspec-*,rcov-*,gems']
    t.spec_opts = ['--color']
  end
  
  desc "Generate an html report"
  Spec::Rake::SpecTask.new('report') do |t|
    t.spec_files = spec_files
    t.rcov = true
    t.rcov_dir = "doc/coverage"
    t.rcov_opts = ['--exclude', 'spec']
    t.spec_opts = ['--color', "--format", "html:doc/reports/specs.html"]
    t.fail_on_error = false
  end

end

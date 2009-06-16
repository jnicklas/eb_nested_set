# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{eb_nested_set}
  s.version = "0.3.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jonas Nicklas"]
  s.autorequire = %q{eb_nested_set}
  s.date = %q{2009-06-16}
  s.description = %q{A cool acts_as_nested_set alternative}
  s.email = %q{jonas.nicklas@gmail.com}
  s.extra_rdoc_files = ["README.md", "LICENSE"]
  s.files = ["LICENSE", "README.md", "Rakefile", "init.rb", "lib/eb_nested_set.rb", "spec/directory_spec.rb", "spec/employee_spec.rb", "spec/nested_set_behavior.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/jnicklas/even_better_nested_set/tree/master}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.2}
  s.summary = %q{A cool acts_as_nested_set alternative}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

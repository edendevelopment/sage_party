require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "sage_party"
    gem.summary = %Q{Simple interface to the SagePay Server service.}
    gem.description = %Q{sage_party is a simple interface to SagePay's Server service built on top of party_resource}
    gem.email = "dev+sage_party@edendevelopment.co.uk"
    gem.homepage = "http://github.com/edendevelopment/sage_party.git"
    gem.authors = ["Tristan Harris", "Steve Tooke"]
    gem.add_runtime_dependency "party_resource", ">= 0.0.2"
    gem.add_runtime_dependency "activesupport", ">= 2.3.5"
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "yard", ">= 0"
    gem.add_development_dependency "webmock", ">= 0"
    gem.files = FileList['lib/**/*.rb']
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.options = ['--no-private']
  end
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end


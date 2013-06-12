# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)
require 'perfectsched/version'

Gem::Specification.new do |gem|
  gem.name        = "perfectsched"
  gem.description = "Highly available distributed cron built on RDBMS"
  gem.homepage    = "https://github.com/treasure-data/perfectsched"
  gem.summary     = gem.description
  gem.version     = PerfectSched::VERSION
  gem.authors     = ["Sadayuki Furuhashi"]
  gem.email       = "frsyuki@gmail.com"
  gem.license     = "Apache 2.0"
  gem.has_rdoc    = false
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "cron-spec", [">= 0.1.2", "<= 0.1.2"]
  gem.add_dependency "sequel", "~> 3.26.0"
  gem.add_dependency "tzinfo", "~> 0.3.29"
  gem.add_dependency "perfectqueue", "~> 0.8.5"
  gem.add_development_dependency "rake", "~> 0.9.2"
  gem.add_development_dependency "rspec", "~> 2.10.0"
  gem.add_development_dependency "simplecov", "~> 0.5.4"
  gem.add_development_dependency "sqlite3", "~> 1.3.3"
end

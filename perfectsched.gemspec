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
  gem.has_rdoc    = false
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "chrono", "~> 0.2.0"
  gem.add_dependency "sequel", "~> 3.48.0"
  gem.add_dependency "tzinfo", "~> 1.1"
  gem.add_dependency "perfectqueue", "~> 0.8.41", "~>0.9"
  gem.add_development_dependency "rake", "~> 0.9.2"
  gem.add_development_dependency "rspec", "~> 3.4.0"
  gem.add_development_dependency "simplecov", "~> 0.10.0"
  gem.add_development_dependency "sqlite3", "~> 1.3.3"
  gem.add_development_dependency "mysql2", "~> 0.3.20"
end

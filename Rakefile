require 'rake'
require 'rake/testtask'
require 'rake/clean'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "perfectsched"
    gemspec.summary = "Highly available distributed cron built on RDBMS or SimpleDB"
    gemspec.author = "Sadayuki Furuhashi"
    gemspec.email = "frsyuki@gmail.com"
    gemspec.homepage = "https://github.com/treasure-data/perfectsched"
    #gemspec.has_rdoc = false
    gemspec.require_paths = ["lib"]
    gemspec.add_dependency "cron-spec", [">= 0.1.2", "<= 0.1.2"]
    gemspec.add_dependency "sequel", "~> 3.26.0"
    gemspec.add_dependency "aws-sdk", "~> 1.1.1"
    gemspec.add_dependency "perfectqueue", "~> 0.7.0"
    gemspec.test_files = Dir["test/**/*.rb", "test/**/*.sh"]
    gemspec.files = Dir["bin/**/*", "lib/**/*"]
    gemspec.executables = ['perfectsched']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

Rake::TestTask.new(:test) do |t|
  t.test_files = Dir['test/*_test.rb']
  t.ruby_opts = ['-rubygems'] if defined? Gem
  t.ruby_opts << '-I.'
end

VERSION_FILE = "lib/perfectsched/version.rb"

file VERSION_FILE => ["VERSION"] do |t|
  version = File.read("VERSION").strip
  File.open(VERSION_FILE, "w") {|f|
    f.write <<EOF
module PerfectSched

VERSION = '#{version}'

end
EOF
  }
end

task :default => [VERSION_FILE, :build]


require 'optparse'
require 'perfectsched/version'

op = OptionParser.new

op.banner += %[ <command>

commands:
    list                             Show list of registered schedules
    add <key> <cron> <data>          Register a new schedule
    delete <key>                     Delete a registered schedule
    run <class>                      Run a worker process
    init                             Initialize a backend database

]
op.version = PerfectSched::VERSION

env = ENV['RAILS_ENV'] || 'development'
config_path = 'config/perfectsched.yml'
include_dirs = []
require_files = []

add_options = {
  :delay => 0,
  :timezone => 'UTC',
  :next_time => nil,
  :next_run_time => nil,
}

op.separator("options:")

op.on('-e', '--environment ENV', 'Framework environment (default: development)') {|s|
  env = s
}

op.on('-c', '--config PATH.yml', 'Path to a configuration file (default: config/perfectsched.yml)') {|s|
  config_path = s
}

op.separator("\noptions for add:")

op.on('-d', '--delay SEC', 'Delay time before running a schedule (default: 0)', Integer) {|i|
  add_options[:delay] = i
}

op.on('-t', '--timezone NAME', 'Set timezone (default: UTC)') {|s|
  add_options[:timezone] = s
}

op.on('-s', '--start UNIXTIME', 'Set the first schedule time (default: now)', Integer) {|i|
  add_options[:next_time] = i
}

op.on('-a', '--at UNIXTIME', 'Set the first run time (default: start+delay)', Integer) {|i|
  add_options[:next_run_time] = i
}

op.separator("\noptions for run:")

op.on('-I', '--include PATH', 'Add $LOAD_PATH directory') {|s|
  include_dirs << s
}

op.on('-r', '--require PATH', 'Require files before starting') {|s|
  require_files << s
}

(class<<self;self;end).module_eval do
  define_method(:usage) do |msg|
    puts op.to_s
    puts "\nerror: #{msg}" if msg
    exit 1
  end
end

begin
  op.parse!(ARGV)

  usage nil if ARGV.empty?

  cmd = ARGV.shift
  case cmd
  when 'list'
    cmd = :list
    usage nil unless ARGV.length == 0

  when 'delete'
    cmd = :delete
    usage nil unless ARGV.length == 1
    key = ARGV[0]

  when 'add'
    cmd = :add
    usage nil unless ARGV.length == 3
    key, cron, data = *ARGV
    require 'json'
    data = JSON.load(data)

  when 'run'
    cmd = :run
    usage nil unless ARGV.length == 1
    klass = ARGV[0]

  when 'init'
    cmd = :init
    usage nil unless ARGV.length == 0

  else
    raise "unknown command: '#{cmd}'"
  end

rescue
  usage $!.to_s
end

require 'yaml'
require 'perfectsched'

config_load_proc = Proc.new {
  yaml = YAML.load(File.read(config_path))
  conf = yaml[env]
  unless conf
    raise "Configuration file #{config_path} doesn't include configuration for environment '#{env}'"
  end
  conf
}

case cmd
when :list
  n = 0
  PerfectSched.open(config_load_proc.call) {|scheds|
    format = "%30s %15s %18s %7s %11s %28s %28s  %s"
    puts format % ['key', 'cron', 'delay', 'timezone', 'next_time', 'next_run_time', 'data']
    scheds.list {|sched|
      next_time = sched.next_time ? Time.at(sched.next_time) : sched.next_time
      next_run_time = sched.next_run_time ? Time.at(sched.next_run_time) : sched.next_run_time
      puts format % [sched.key, sched.cron, sched.delay, sched.timezone, next_time, next_run_time, sched.data]
      n += 1
    }
  }
  puts "#{n} entries."

when :delete
  PerfectSched.open(config_load_proc.call) {|scheds|
    scheds[key].delete!
  }

when :add
  PerfectSched.open(config_load_proc.call) {|scheds|
    add_options[:cron] = cron
    add_options[:data] = data
    scheds.add(key, add_options)
  }

when :run
  include_dirs.each {|path|
    $LOAD_PATH << File.expand_path(path)
  }
  require_files.each {|file|
    require file
  }
  klass = Object.const_get(klass)
  PerfectSched::Worker.run(klass, &config_load_proc)

when :init
  PerfectSched.open(config_load_proc.call) {|scheds|
    scheds.client.init_database
  }
end


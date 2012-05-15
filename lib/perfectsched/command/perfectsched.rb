require 'optparse'
require 'perfectsched/version'

op = OptionParser.new

op.banner += %[ <command>

commands:
    list                             Show list of registered schedules
    add <key> <type> <cron> <data>   Register a new schedule
    delete <key>                     Delete a registered schedule
    run <class>                      Run a worker process

]
op.version = PerfectSched::VERSION

env = ENV['RAILS_ENV'] || 'development'
config_path = 'config/perfectsched.yml'
require_files = []

add_config = {
  :delay => 0,
  :timezone => 'UTC',
  :start => nil,
  :run => nil,
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
  add_config[:delay] = i
}

op.on('-t', '--timezone NAME', 'Set timezone (default: UTC)') {|s|
  add_config[:timezone] = s
}

op.on('-s', '--start UNIXTIME', 'Set the first schedule time (default: now)', Integer) {|i|
  add_config[:start] = i
}

op.on('-a', '--at UNIXTIME', 'Set the first run time (default: start+delay)', Integer) {|i|
  add_config[:run] = i
}

op.separator("\noptions for run:")

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
    key = ARGV[0]
    usage nil unless ARGV.length == 0

  when 'add'
    cmd = :add
    usage nil unless ARGV.length == 3
    key, type, cron, data = *ARGV
    require 'json'
    data = JSON.load(data)

  when 'run'
    cmd = :run
    usage nil unless ARGV.length == 1
    klass = ARGV[0]

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
  PerfectSched.open(config_load_proc.call) {|scheds|
    scheds.list {|sched|
      # TODO
      p sched
    }
  }

when :delete
  PerfectSched.open(config_load_proc.call) {|scheds|
    scheds[key].delete!
  }

when :add
  PerfectSched.open(config_load_proc.call) {|scheds|
    scheds.submit(key, type, {:cron=>cron, :timezone=>timezone, :data=>data})
  }

when :run
  require_files.each {|file|
    require file
  }
  klass = Object.const_get(klass)
  PerfectSched::Daemon.run(klass, &config_load_proc)
end


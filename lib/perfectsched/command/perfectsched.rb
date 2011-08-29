require 'optparse'
require 'perfectsched/version'

op = OptionParser.new

op.banner += ""
op.version = PerfectSched::VERSION

type = nil
id = nil
confout = nil

conf = {
  :timeout => 600,
  :poll_interval => 1,
  #:expire => 345600,
}

add_conf = {
  :delay => 0,
}


op.on('--setup PATH.yaml', 'Write example configuration file') {|s|
  type = :conf
  confout = s
}

op.on('-f', '--file PATH.yaml', 'Set path to the configuration file') {|s|
  conf[:file] = s
}

op.separator("")

op.on('--list', 'Show registered schedule', TrueClass) {|b|
  type = :list
}

op.on('--delete ID', 'Delete a registered schedule') {|s|
  type = :delete
  id = s
}

op.separator("")

op.on('--add <ID> <CRON> <DATA>', 'Register a schedule') {|s|
  type = :add
  id = s
}

op.on('-d', '--delay SEC', 'Delay time before running a schedule (default: 0)', Integer) {|i|
  add_conf[:delay] = i
}

op.on('-s', '--start UNIXTIME', 'Start time to run a schedule (default: now)', Integer) {|i|
  add_conf[:start] = i
}

op.separator("")

op.on('-S', '--modify-sched <ID> <CRON>', 'Modify schedule of a registered schedule') {|s|
  type = :modify_sched
  id = s
}

op.on('-D', '--modify-delay <ID> <DELAY>', 'Modify delay of a registered schedule') {|s|
  type = :modify_delay
  id = s
}

op.on('-J', '--modify-data <ID> <DATA>', 'Modify data of a registered schedule') {|s|
  type = :modify_data
  id = s
}

op.separator("")

op.on('-b', '--daemon PIDFILE', 'Daemonize (default: foreground)') {|s|
  conf[:daemon] = s
}

op.on('-o', '--log PATH', "log file path") {|s|
  conf[:log] = s
}

op.on('-v', '--verbose', "verbose mode", TrueClass) {|b|
  conf[:verbose] = true
}


(class<<self;self;end).module_eval do
  define_method(:usage) do |msg|
    puts op.to_s
    puts "error: #{msg}" if msg
    exit 1
  end
end


begin
  op.parse!(ARGV)

  if type == :add
    if ARGV.length != 2
      usage nil
    end
    add_conf[:cron] = ARGV[0]
    add_conf[:data] = ARGV[1]

  elsif type == :modify_sched
    if ARGV.length != 1
      usage nil
    end
    add_conf[:cron] = ARGV[0]

  elsif type == :modify_data
    if ARGV.length != 1
      usage nil
    end
    add_conf[:data] = ARGV[0]

  elsif type == :modify_delay
    if ARGV.length != 1 || ARGV[0].to_i.to_s != ARGV[0]
      usage nil
    end
    add_conf[:delay] = ARGV[0].to_i

  elsif ARGV.length != 0
    usage nil
  end

  type ||= :run

  if confout
    require 'yaml'

    File.open(confout, "w") {|f|
      f.write <<EOF
---
timeout: 300
poll_interval: 1
backend:
  database: "mysql://user:password@localhost/mydb"
  table: "perfectsched"
  #simpledb: your-simpledb-domain-name-for-scheduler
  #aws_key_id: "AWS_ACCESS_KEY_ID"
  #aws_secret_key: "AWS_SECRET_ACCESS_KEY"
queue:
  database: "mysql://user:password@localhost/mydb"
  table: "perfectqueue"
  #simpledb: your-simpledb-domain-name-for-queue
  #aws_key_id: "AWS_ACCESS_KEY_ID"
  #aws_secret_key: "AWS_SECRET_ACCESS_KEY"
EOF
    }
    exit 0
  end

  unless conf[:file]
    raise "-f, --file PATH.yaml option is required"
  end

rescue
  usage $!.to_s
end


require 'perfectsched'
require 'perfectqueue'

require 'yaml'
yaml = YAML.load File.read(conf[:file])

yaml.each_pair {|k,v|
  conf[k.to_sym] = v
}

conf[:timeout] ||= 60
conf[:poll_interval] ||= 1

# backend
bconf = yaml['backend']
if domain = bconf['simpledb']
  require 'perfectsched/backend/simpledb'
  key_id = bconf['aws_key_id'] || ENV['AWS_ACCESS_KEY_ID']
  secret_key = bconf['aws_secret_key'] || ENV['AWS_SECRET_ACCESS_KEY']
  backend = PerfectSched::SimpleDBBackend.new(key_id, secret_key, domain)
  if type != :run
    backend.use_consistent_read
  end

elsif uri = bconf['database']
  require 'perfectsched/backend/rdb'
  table = bconf['table'] || "perfectsched"
  backend = PerfectSched::RDBBackend.new(uri, table)

else
  $stderr.puts "Invalid configuration file: backend section is required"
  exit 1
end

# queue
bconf = yaml['queue']
if domain = bconf['simpledb']
  require 'perfectqueue/backend/simpledb'
  key_id = bconf['aws_key_id'] || ENV['AWS_ACCESS_KEY_ID']
  secret_key = bconf['aws_secret_key'] || ENV['AWS_SECRET_ACCESS_KEY']
  queue = PerfectQueue::SimpleDBBackend.new(key_id, secret_key, domain)

elsif uri = bconf['database']
  require 'perfectqueue/backend/rdb'
  table = bconf['table'] || "perfectqueue"
  queue = PerfectQueue::RDBBackend.new(uri, table)

else
  $stderr.puts "Invalid configuration file: queue section is required"
  exit 1
end

require 'logger'

case type
when :list
  format = "%26s %20s %8s %26s %26s  %s"
  puts format % ["id", "schedule", "delay", "next time", "next run", "data"]
  n = 0
  backend.list {|id,cron,delay,data,next_time,timeout|
    puts format % [id, cron, delay, Time.at(next_time), Time.at(timeout), data]
    n += 1
  }
  puts "#{n} entries."

when :delete
  deleted = backend.delete(id)
  if deleted
    puts "Schedule id=#{id} is deleted."
  else
    puts "Schedule id=#{id} does not exist."
    exit 1
  end

when :add
  cron = add_conf[:cron]
  data = add_conf[:data]
  delay = add_conf[:delay]
  start = add_conf[:start] || Time.now.to_i

  added = backend.add(id, cron, delay, data, start)
  if added
    puts "Schedule id=#{id} is added."
  else
    puts "Schedule id=#{id} already exists."
    exit 1
  end

when :modify_sched, :modify_delay, :modify_data
  cron, delay, data = backend.get(id)
  unless cron
    puts "Schedule id=#{id} does not exist."
    exit 1
  end

  case type
  when :modify_sched
    cron = add_conf[:cron]
    modified = backend.modify_sched(id, cron, delay)

  when :modify_delay
    delay = add_conf[:delay]
    modified = backend.modify_sched(id, cron, delay)

  when :modify_data
    data = add_conf[:data]
    modified = backend.modify_data(id, data)
  end

  if modified
    puts "Schedule id=#{id} is modified."
  else
    puts "Schedule id=#{id} does not exist."
    exit 1
  end

when :run
  if conf[:daemon]
    exit!(0) if fork
    Process.setsid
    exit!(0) if fork
    File.umask(0)
    STDIN.reopen("/dev/null")
    STDOUT.reopen("/dev/null", "w")
    STDERR.reopen("/dev/null", "w")
    File.open(conf[:daemon], "w") {|f|
      f.write Process.pid.to_s
    }
  end

  if log_file = conf[:log]
    log_out = File.open(conf[:log], "a")
  else
    log_out = STDOUT
  end

  log = Logger.new(log_out)
  if conf[:verbose]
    log.level = Logger::DEBUG
  else
    log.level = Logger::INFO
  end

  engine = PerfectSched::Engine.new(backend, queue, log, conf)

  trap :INT do
    log.info "shutting down..."
    engine.stop
  end

  trap :TERM do
    log.info "shutting down..."
    engine.stop
  end

  trap :HUP do
    if log_file
      log_out.reopen(log_file, "a")
    end
  end

  log.info "PerfectSched-#{PerfectSched::VERSION}"

  begin
    engine.run
    engine.shutdown
  rescue
    log.error $!.to_s
    $!.backtrace.each {|x|
      log.error "  #{x}"
    }
    exit 1
  end
end


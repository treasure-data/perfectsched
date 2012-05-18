# PerfectSched

PerfectSched is a highly available distributed cron built on top of RDBMS.

It provides at-least-once semantics; Even if a worker node fails during process a task, the task is retried by another worker.

PerfectSched also guarantees that only one worker server processes a task if the server is alive.

All you have to consider is implementing idempotent worker programs. It's recommended to use [PerfectQueue](https://github.com/treasure-data/perfectqueue) with PerfectSched.


## API overview

```ruby
# open a schedule collection
PerfectSched.open(config, &block)  #=> #<ScheduleCollection>

# add a schedule
ScheduleCollection#add(task_id, type, options)

# poll a scheduled task
# (you don't have to use this method directly. see following sections)
ScheduleCollection#poll  #=> #<Task>

# get data associated with a task
Task#data  #=> #<Hash>

# finish a task
Task#finish!

# retry a task
Task#retry!
```

Example:

```ruby
# submit a task
PerfectSched.open(config) {|sc|
  data = {'key'=>"value"}
  options = {
    :cron => '0 * * * *',
    :delay => 30,
    :timezone => 'Asia/Tokyo',
    :next_time => Time.parse('2013-01-01 00:00:00 +0900').to_i,
    :data => data,
  }
  sc.submit("sched-id", "type1", options)
}
```


## Writing a worker application

### 1. Implement PerfectSched::Application::Base

```ruby
class TestHandler < PerfectSched::Application::Base
  # implement run method
  def run
    # do something ...
    puts "acquired task: #{task.inspect}"

    # call task.finish!, task.retry! or task.release!
    task.finish!
  end
end

### 2. Implement PerfectSched::Application::Dispatch

```ruby
class Dispatch < PerfectSched::Application::Dispatch
  # describe routing
  route "type1" => TestHandler
  route /^regexp-.*$/ => :TestHandler  # String or Regexp => Class or Symbol
end
```

### 3. Run the worker
In a launcher script or rake file:

```
# run PerfectSched::Worker with the dispatcher
system('perfectsched run -I. -rapp/schedules/dispatch Dispatch')
```

or:

```ruby
require 'app/schedules/dispatch'
PerfectSched::Worker.run(Dispatch) {
  # this method is called when the worker process is restarted
  raw = File.read('config/perfectsched.yml')
  yml = YAJL.load(raw)
  yml[ENV['RAILS_ENV'] || 'development']
}
```

### Signal handlers

- **TERM,INT,QUIT:** shutdown
- **USR1,HUP:** restart
- **USR2:** reopen log files

## Configuration

- **type:** backend type (required; see following sections)
- **log:** log file path (default: use stderr)
- **poll\_interval:** interval to poll tasks in seconds (default: 1.0 sec)
- **timezone:** default timezone (default: 'UTC')
- **alive\_time:** duration to continue a heartbeat request (default: 300 sec)
- **retry\_wait:** duration to retry a retried task (default: 300 sec)

## Backend types

### rdb\_compat

additional configuration:

- **url:** URL to the RDBMS (example: 'mysql://user:password@host:port/database')
- **table:** name of the table to use


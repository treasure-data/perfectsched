# PerfectSched

[![Build Status](https://travis-ci.org/treasure-data/perfectsched.svg?branch=master)](https://travis-ci.org/treasure-data/perfectsched)

PerfectSched is a highly available distributed cron built on top of RDBMS.

It provides at-least-once semantics; Even if a worker node fails during process a task, the task is retried by another worker.

PerfectSched also guarantees that only one worker server processes a task if the server is alive.

All you have to consider is implementing idempotent worker programs. It's recommended to use [PerfectQueue](https://github.com/treasure-data/perfectqueue) with PerfectSched.


## API overview

```
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

# create a schedule reference
ScheduleCollection#[](key)  #=> #<Schedule>

# chack the existance of the schedule
Schedule#exists?

# delete a schedule
Schedule#delete!
```

### Error classes

```
ScheduleError < StandardError

##
# Workers may get these errors:
#

AlreadyFinishedError < ScheduleError

NotFoundError < ScheduleError

PreemptedError < ScheduleError

ProcessStopError < RuntimeError

##
# Client or other situation:
#

ConfigError < RuntimeError

AlreadyExistsError < ScheduleError

NotSupportedError < ScheduleError
```


### Example

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
```

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

```ruby
system('perfectsched run -I. -rapp/schedules/dispatch Dispatch')
```

or:

```ruby
require 'perfectsched'
require 'app/schedules/dispatch'

PerfectSched::Worker.run(Dispatch) {
  # this method is called when the worker process is restarted
  raw = File.read('config/perfectsched.yml')
  yml = YAJL.load(raw)
  yml[ENV['RAILS_ENV'] || 'development']
}
```

### Signal handlers

- **TERM**,**INT**,**QUIT:** shutdown
- **USR1**,**HUP:** restart
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

### rdb

Not implemented yet.


## Command line management tool

```
Usage: perfectsched [options] <command>

commands:
    list                             Show list of registered schedules
    add <key> <type> <cron> <data>   Register a new schedule
    delete <key>                     Delete a registered schedule
    run <class>                      Run a worker process
    init                             Initialize a backend database

options:
    -e, --environment ENV            Framework environment (default: development)
    -c, --config PATH.yml            Path to a configuration file (default: config/perfectsched.yml)

options for add:
    -d, --delay SEC                  Delay time before running a schedule (default: 0)
    -t, --timezone NAME              Set timezone (default: UTC)
    -s, --start UNIXTIME             Set the first schedule time (default: now)
    -a, --at UNIXTIME                Set the first run time (default: start+delay)

options for run:
    -I, --include PATH               Add $LOAD_PATH directory
    -r, --require PATH               Require files before starting
```

### initializing a database

    # assume that the config/perfectsched.yml exists
    $ perfectsched init

### submitting a task

    $ perfectsched add s1 user_task '* * * * *' '{}'

### listing tasks

    $ perfectsched list
                               key            type               cron   delay    timezone                    next_time                next_run_time  data
                                s1       user_task          * * * * *       0         UTC      2012-05-18 22:04:00 UTC      2012-05-18 22:04:00 UTC  {}
    1 entries.

### delete a schedule

    $ perfectsched delete s1

### running a worker

    $ perfectsched run -I. -Ilib -rconfig/boot.rb -rapps/schedules/schedule_dispatch.rb ScheduleDispatch


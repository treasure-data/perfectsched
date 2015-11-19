require 'spec_helper'

class TestHandler < PerfectSched::Application::Base
  def run
    puts "TestHandler: #{task}"
    if task.data['raise_error']
      raise "expected error test"
    end
    if num = task.data['sleep']
      sleep num
    end
    puts "Task finished"
  end

  def kill(reason)
    puts "kill: #{reason.class}: #{reason}"
  end
end

class TestApp < PerfectSched::Application::Dispatch
  route 'test' => TestHandler
end

describe Worker do
  before do
    create_test_sched.close
    @worker = Worker.new(TestApp, test_sched_config)
    @thread = Thread.new {
      @worker.run
    }
  end

  after do
    @worker.stop
    @thread.join
  end

  def add(*args)
    sc = get_test_sched
    sc.add(*args)
    sc.close
  end

  it 'run' do
    expect_any_instance_of(TestHandler).to receive(:run).once
    add('key', 'test', {:cron=>'* * * * *', :next_time=>Time.now.to_i-60})
    sleep 2
  end

  it 'term signal' do
    sleep 1
    Process.kill(:TERM, Process.pid)
    puts "finish expected..."
    @thread.join
  end

end


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
  route 'key' => TestHandler
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
    TestHandler.any_instance.should_receive(:run).once
    add('key', {:cron=>'* * * * *', :next_time=>Time.now.to_i-60})
    sleep 2
  end

end


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
    puts "task finished"
  end

  def kill(reason)
    puts "#{reason.class}: #{reason}"
  end
end

class TestApp < PerfectSched::Application::Dispatch
  LATER = []

  def self.later(&block)
    LATER << block
  end

  def self.new(task)
    # TODO rspec doesn't work with fork?
    #LATER.each {|block| block.call }
    super
  end

  route 'test' => TestHandler
end

describe Worker do
  before do
    create_test_sched.close
    TestApp::LATER.clear
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
    TestApp.later do
      TestHandler.any_instance.should_receive(:run).once
    end
    add('key', 'test', {:cron=>'* * * * *', :next_time=>Time.now.to_i-60})
    sleep 2
  end

end


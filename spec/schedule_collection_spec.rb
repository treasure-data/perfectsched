
describe ScheduleCollection do
  let :sc do
    create_test_sched
  end

  after do
    sc.client.close
  end

  it 'is a ScheduleCollection' do
    sc.class.should == PerfectSched::ScheduleCollection
  end

  it 'succeess add' do
    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
  end

  it 'fail duplicated add' do
    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})

    lambda {
      sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
    }.should raise_error AlreadyExistsError

    sc['sched01'].delete!

    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
  end

  it 'acquire' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    s01 = sc.add('sched01', 't01', :cron=>"* * * * *", :data=>{'k'=>1}, :next_time=>time)

    t01 = sc.poll(:alive_time=>120, :now=>time)
    t01.key.should == 'sched01'
    t01.type.should == 't01'
    t01.cron.should == "* * * * *"
    t01.delay.should == 0
    t01.data.should == {'k'=>1}
    t01.scheduled_time.should == time

    t02 = sc.poll(:alive_time=>120, :now=>time+60)
    t02.should == nil

    t01.finish!

    t04 = sc.poll(:alive_time=>120, :now=>time+60)
    t04.key.should == 'sched01'
    t01.type.should == 't01'
    t04.cron.should == "* * * * *"
    t04.delay.should == 0
    t04.data.should == {'k'=>1}
    t04.scheduled_time.should == time+60
  end

  it 'timezone' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    s01 = sc.add('sched01', 't01', :cron=>"0 0 * * *", :next_time=>time-60, :timezone=>'UTC')
    #s01.class.should == Schedule
    #s01.key.should == 'sched01'

    s02 = sc.add('sched02', 't01', :cron=>"0 0 * * *", :next_time=>time-60, :timezone=>'Asia/Tokyo')
    #s02.class.should == Schedule
    #s02.key.should == 'sched02'

    t01 = sc.poll(:alive_time=>86400, :now=>time)
    t01.class.should == Task
    t01.key.should == 'sched01'
    t01.type.should == 't01'
    t01.scheduled_time.should == time

    t02 = sc.poll(:alive_time=>86400, :now=>time+54000)
    t02.class.should == Task
    t02.key.should == 'sched02'
    t02.type.should == 't01'
    t02.scheduled_time.should == time+54000
  end

  it 'delay' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    s01 = sc.add('sched01', 't01', :cron=>"0 * * * *", :delay=>30, :next_time=>time, :timezone=>'UTC')

    t01 = sc.poll(:alive_time=>86400, :now=>time)
    t01.should == nil

    t02 = sc.poll(:alive_time=>86400, :now=>time+30)
    t02.class.should == Task
    t02.key.should == 'sched01'
    t02.type.should == 't01'
    t02.scheduled_time.should == time
    t02.delay.should == 30

    t02.finish!

    t03 = sc.poll(:alive_time=>86400, :now=>time+3600)
    t03.should == nil

    t04 = sc.poll(:alive_time=>86400, :now=>time+3630)
    t04.class.should == Task
    t04.key.should == 'sched01'
    t04.type.should == 't01'
    t04.scheduled_time.should == time+3600
    t04.delay.should == 30
  end

  it 'invalid cron format' do
    lambda {
      sc.add('sched01', 't01', :cron=>'???')
    }.should raise_error ArgumentError

    lambda {
      sc.add('sched01', 't01', :cron=>'* * * * * *')
    }.should raise_error ArgumentError
  end

  it 'fail duplicated add' do
    sc.add('sched01', 't01', :cron=>"0 * * * *")
    lambda {
      sc.add('sched01', 't01', :cron=>"0 * * * *")
    }.should raise_error AlreadyExistsError

    sc['sched01'].delete!

    sc.add('sched01', 't01', :cron=>"0 * * * *")
  end

  it 'list' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    sc.add('sched01', 't01', :cron=>"0 * * * *", :next_time=>time, :delay=>1)
    sc.add('sched02', 't02', :cron=>"0 * * * *", :next_time=>time, :delay=>2)
    sc.add('sched03', 't03', :cron=>"0 * * * *", :next_time=>time, :delay=>3, :next_run_time=>time+3600)

    a = []
    sc.list {|s|
      a << s
    }
    a.sort_by! {|s| s.key }

    s01 = a.shift
    s01.class.should == ScheduleWithMetadata
    s01.key.should == 'sched01'
    s01.type.should == 't01'
    s01.cron.should == '0 * * * *'
    s01.delay.should == 1
    s01.next_time.should == time
    s01.next_run_time.should == time+1

    s02 = a.shift
    s02.class.should == ScheduleWithMetadata
    s02.key.should == 'sched02'
    s02.type.should == 't02'
    s02.cron.should == '0 * * * *'
    s02.delay.should == 2
    s02.next_time.should == time
    s02.next_run_time.should == time+2

    s03 = a.shift
    s03.class.should == ScheduleWithMetadata
    s03.key.should == 'sched03'
    s03.type.should == 't03'
    s03.cron.should == '0 * * * *'
    s03.delay.should == 3
    s03.next_time.should == time
    s03.next_run_time.should == time+3600
  end
end


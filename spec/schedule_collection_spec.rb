
describe ScheduleCollection do
  let :sc do
    create_test_sched
  end

  after do
    sc.client.close
  end

  it 'is a ScheduleCollection' do
    expect(sc.class).to eq(PerfectSched::ScheduleCollection)
  end

  it 'succeess add' do
    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
  end

  it 'fail duplicated add' do
    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})

    expect {
      sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
    }.to raise_error AlreadyExistsError

    sc['sched01'].delete!

    sc.add('sched01', 't01', {:cron=>'* * * * *', :timezone=>'UTC'})
  end

  it 'acquire' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    s01 = sc.add('sched01', 't01', :cron=>"* * * * *", :data=>{'k'=>1}, :next_time=>time)

    t01 = sc.poll(:alive_time=>120, :now=>time)
    expect(t01.key).to eq('sched01')
    expect(t01.type).to eq('t01')
    expect(t01.cron).to eq("* * * * *")
    expect(t01.delay).to eq(0)
    expect(t01.data).to eq({'k'=>1})
    expect(t01.scheduled_time).to eq(time)

    t02 = sc.poll(:alive_time=>120, :now=>time+60)
    expect(t02).to eq(nil)

    t01.finish!

    t04 = sc.poll(:alive_time=>120, :now=>time+60)
    expect(t04.key).to eq('sched01')
    expect(t01.type).to eq('t01')
    expect(t04.cron).to eq("* * * * *")
    expect(t04.delay).to eq(0)
    expect(t04.data).to eq({'k'=>1})
    expect(t04.scheduled_time).to eq(time+60)
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
    expect(t01.class).to eq(Task)
    expect(t01.key).to eq('sched01')
    expect(t01.type).to eq('t01')
    expect(t01.scheduled_time).to eq(time)

    t02 = sc.poll(:alive_time=>86400, :now=>time+54000)
    expect(t02.class).to eq(Task)
    expect(t02.key).to eq('sched02')
    expect(t02.type).to eq('t01')
    expect(t02.scheduled_time).to eq(time+54000)
  end

  it 'delay' do
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    s01 = sc.add('sched01', 't01', :cron=>"0 * * * *", :delay=>30, :next_time=>time, :timezone=>'UTC')

    t01 = sc.poll(:alive_time=>86400, :now=>time)
    expect(t01).to eq(nil)

    t02 = sc.poll(:alive_time=>86400, :now=>time+30)
    expect(t02.class).to eq(Task)
    expect(t02.key).to eq('sched01')
    expect(t02.type).to eq('t01')
    expect(t02.scheduled_time).to eq(time)
    expect(t02.delay).to eq(30)

    t02.finish!

    t03 = sc.poll(:alive_time=>86400, :now=>time+3600)
    expect(t03).to eq(nil)

    t04 = sc.poll(:alive_time=>86400, :now=>time+3630)
    expect(t04.class).to eq(Task)
    expect(t04.key).to eq('sched01')
    expect(t04.type).to eq('t01')
    expect(t04.scheduled_time).to eq(time+3600)
    expect(t04.delay).to eq(30)
  end

  it 'invalid cron format' do
    expect {
      sc.add('sched01', 't01', :cron=>'???')
    }.to raise_error ArgumentError

    expect {
      sc.add('sched01', 't01', :cron=>'* * * * * *')
    }.to raise_error ArgumentError
  end

  it 'fail duplicated add' do
    sc.add('sched01', 't01', :cron=>"0 * * * *")
    expect {
      sc.add('sched01', 't01', :cron=>"0 * * * *")
    }.to raise_error AlreadyExistsError

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
    expect(s01.class).to eq(ScheduleWithMetadata)
    expect(s01.key).to eq('sched01')
    expect(s01.type).to eq('t01')
    expect(s01.cron).to eq('0 * * * *')
    expect(s01.delay).to eq(1)
    expect(s01.next_time).to eq(time)
    expect(s01.next_run_time).to eq(time+1)

    s02 = a.shift
    expect(s02.class).to eq(ScheduleWithMetadata)
    expect(s02.key).to eq('sched02')
    expect(s02.type).to eq('t02')
    expect(s02.cron).to eq('0 * * * *')
    expect(s02.delay).to eq(2)
    expect(s02.next_time).to eq(time)
    expect(s02.next_run_time).to eq(time+2)

    s03 = a.shift
    expect(s03.class).to eq(ScheduleWithMetadata)
    expect(s03.key).to eq('sched03')
    expect(s03.type).to eq('t03')
    expect(s03.cron).to eq('0 * * * *')
    expect(s03.delay).to eq(3)
    expect(s03.next_time).to eq(time)
    expect(s03.next_run_time).to eq(time+3600)
  end
end


require File.dirname(__FILE__)+'/test_helper'

class BackendTest < Test::Unit::TestCase
  SCHED = 120
  TIMEOUT = 60
  DB_PATH = File.dirname(__FILE__)+'/test.db'
  DB_URI = "sqlite://#{DB_PATH}"

  def clean_backend
    @key_prefix = "test-#{"%08x"%rand(2**32)}-"
    db = open_backend
    db.list {|id,cron,delay,data,next_time,timeout|
      db.delete(id)
    }
    FileUtils.rm_f DB_PATH
  end

  def open_backend
    #PerfectSched::SimpleDBBackend.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'], 'perfectsched-test-1').use_consistent_read
    db = PerfectSched::RDBBackend.new(DB_URI, "perfectdb_test")
    db.create_tables
    db
  end

  it 'acquire' do
    clean_backend

    db1 = open_backend
    db2 = open_backend
    db3 = open_backend

    time = 0

    ok = db1.add(@key_prefix+'test1', "* * * * *", 0, 'data1', time)
    assert_equal true, ok

    token, task = db2.acquire(180, 60)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal "* * * * *", task.cron
    assert_equal 0, task.delay
    assert_equal 'data1', task.data
    assert_equal 60, task.time

    token_, task_ = db3.acquire(180, 60)
    assert_equal nil, token_

    token_, task_ = db3.acquire(240, 120)
    assert_equal nil, token_

    ok = db2.finish(token, 120, 120)
    assert_equal true, ok

    token, task = db3.acquire(240, 120)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal "* * * * *", task.cron
    assert_equal 0, task.delay
    assert_equal 'data1', task.data
    assert_equal 120, task.time
  end

  it 'timeout' do
    clean_backend

    db1 = open_backend
    db2 = open_backend
    db3 = open_backend

    time = 0

    ok = db1.add(@key_prefix+'test1', "* * * * *", 0, 'data1', time)
    assert_equal true, ok

    token, task = db2.acquire(180, 60)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal "* * * * *", task.cron
    assert_equal 0, task.delay
    assert_equal 'data1', task.data
    assert_equal 60, task.time

    token, task = db3.acquire(240, 180)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal "* * * * *", task.cron
    assert_equal 0, task.delay
    assert_equal 'data1', task.data
    assert_equal 60, task.time
  end

  it 'delay' do
    clean_backend

    db1 = open_backend
    db2 = open_backend
    db3 = open_backend

    time = 0

    ok = db1.add(@key_prefix+'test1', "* * * * *", 30, 'data1', time)
    assert_equal true, ok

    token_, task_ = db2.acquire(180, 60)
    assert_equal nil, token_

    token, task = db2.acquire(210, 90)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal "* * * * *", task.cron
    assert_equal 30, task.delay
    assert_equal 'data1', task.data
    assert_equal 60, task.time
  end

  it 'invalid format' do
    clean_backend

    db1 = open_backend

    assert_raise(RuntimeError) do
      db1.add('k', '???', 0, 'data1', 0)
    end

    assert_raise(RuntimeError) do
      db1.add('k', '* * * * * *', 0, 'data1', 0)
    end
  end

  it 'unique id' do
    clean_backend

    db1 = open_backend
    time = 0
    key = @key_prefix+'test1'

    ok = db1.add(key, "* * * * *", 0, 'data1', time)
    assert_equal true, ok

    ok = db1.add(key, "* * * * *", 0, 'data1', time)
    assert_not_equal true, ok

    ok = db1.delete(key)
    assert_equal true, ok

    ok = db1.add(key, "* * * * *", 0, 'data1', time)
    assert_equal true, ok
  end

  it 'modify' do
    clean_backend

    db1 = open_backend
    time = 0
    key = @key_prefix+'test1'

    ok = db1.add(key, "* * * * *", 0, 'data1', time)
    assert_equal true, ok

    cron, delay, data = db1.get(key)
    assert_equal "* * * * *", cron
    assert_equal 0, delay
    assert_equal 'data1', data

    ok = db1.modify_sched(key, "* * * * 1", 10)
    assert_equal true, ok

    cron, delay, data = db1.get(key)
    assert_equal "* * * * 1", cron
    assert_equal 10, delay
    assert_equal 'data1', data

    ok = db1.modify_data(key, "data2")
    assert_equal true, ok

    cron, delay, data = db1.get(key)
    assert_equal "* * * * 1", cron
    assert_equal 10, delay
    assert_equal 'data2', data

    ok = db1.modify(key, "* * * * 2", 20, "data3", nil)
    assert_equal true, ok

    cron, delay, data = db1.get(key)
    assert_equal "* * * * 2", cron
    assert_equal 20, delay
    assert_equal 'data3', data
  end

  it 'timezone' do
    clean_backend

    db1 = open_backend
    time = 1323820800  # 2011-12-14 00:00:00 UTC

    ok = db1.add(@key_prefix+'test1', "0 0 * * *", 0, '', time-60, 'UTC')
    assert_equal true, ok

    ok = db1.add(@key_prefix+'test2', "0 0 * * *", 0, '', time-60, 'Asia/Tokyo')
    assert_equal true, ok

    token, task = db1.acquire(time+86400, time)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test1', task.id
    assert_equal time, task.time

    token, task = db1.acquire(time+54000+86400, time+54000)
    assert_not_equal nil, task
    assert_equal @key_prefix+'test2', task.id
    assert_equal time+54000, task.time
  end
end


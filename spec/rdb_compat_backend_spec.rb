require 'spec_helper'
require 'perfectsched/backend/rdb_compat'

describe Backend::RDBCompatBackend do
  let :sc do
    FileUtils.rm_f 'spec/test.db'
    sc = PerfectSched.open({:type=>'rdb_compat', :url=>'sqlite://spec/test.db', :table=>'test_scheds'})
    sc.client.init_database
    sc
  end

  let :client do
    sc.client
  end

  let :backend do
    client.backend
  end

  it 'backward compatibility 1' do
    backend.db["INSERT INTO test_scheds (id, timeout, next_time, cron, delay, data, timezone) VALUES (?, ?, ?, ?, ?, ?, ?)", "maint_sched.1.do_hourly", 1339812000, 1339812000, "0 * * * *", 0, {"account_id"=>1}.to_json, "UTC"].insert
    ts = backend.acquire(60, 1, {:now=>1339812003})
    ts.should_not == nil
    t = ts[0]
    t.data.should == {'account_id'=>1}
    t.key.should == 'maint_sched.1.do_hourly'
    t.next_time.should == 1339812000
  end

  it 'backward compatibility 2' do
    backend.db["INSERT INTO test_scheds (id, timeout, next_time, cron, delay, data, timezone) VALUES (?, ?, ?, ?, ?, ?, ?)", "merge", 1339812060, 1339812000, "@hourly", 60, '', "Asia/Tokyo"].insert
    ts = backend.acquire(60, 1, {:now=>1339812060})
    t = ts[0]
    t.data.should == {}
    t.key.should == 'merge'
    t.next_time.should == 1339812000
  end
end


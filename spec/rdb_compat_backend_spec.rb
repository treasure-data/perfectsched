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
    expect(ts).not_to eq(nil)
    t = ts[0]
    expect(t.data).to eq({'account_id'=>1})
    expect(t.type).to eq('maint_sched')
    expect(t.key).to eq('maint_sched.1.do_hourly')
    expect(t.next_time).to eq(1339812000)
  end

  it 'backward compatibility 2' do
    backend.db["INSERT INTO test_scheds (id, timeout, next_time, cron, delay, data, timezone) VALUES (?, ?, ?, ?, ?, ?, ?)", "merge", 1339812060, 1339812000, "@hourly", 60, '', "Asia/Tokyo"].insert
    ts = backend.acquire(60, 1, {:now=>1339812060})
    t = ts[0]
    expect(t.data).to eq({})
    expect(t.type).to eq('merge')
    expect(t.key).to eq('merge')
    expect(t.next_time).to eq(1339812000)
  end
end


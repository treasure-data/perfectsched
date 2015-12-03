require 'spec_helper'
require 'perfectsched/backend/rdb_compat'

describe Backend::RDBCompatBackend do
  let (:now){ Time.now.to_i }
  let (:client){ double('client') }
  let (:config){ {url: 'sqlite://spec/test.db', table: 'test_scheds'} }
  let (:db) do
    d = Backend::RDBCompatBackend.new(client, config)
    s = d.db
    s.tables.each{|t| s.drop_table(t) }
    d.init_database(nil)
    d
  end

  context 'compatibility' do
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

  context '.new' do
    let (:client){ double('client') }
    let (:table){ double('table') }
    it 'raises error unless url' do
      expect{Backend::RDBCompatBackend.new(client, {})}.to raise_error(ConfigError)
    end
    it 'raises error unless table' do
      expect{Backend::RDBCompatBackend.new(client, {url: ''})}.to raise_error(ConfigError)
    end
    it 'supports sqlite' do
      config = {url: 'sqlite://localhost', table: table}
      expect(Backend::RDBCompatBackend.new(client, config)).to be_an_instance_of(Backend::RDBCompatBackend)
    end
    it 'supports mysql' do
      config = {url: 'mysql://root:@localhost/perfectsched_test', table: table}
      expect(Backend::RDBCompatBackend.new(client, config)).to be_an_instance_of(Backend::RDBCompatBackend)
    end
    it 'doesn\'t support postgres' do
      config = {url: 'postgres://localhost', table: table}
      expect{Backend::RDBCompatBackend.new(client, config)}.to raise_error(ConfigError)
    end
  end

  context '#init_database' do
    it 'creates the table' do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
    end
  end

  context '#get_schedule_metadata' do
    before do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
    end
    it 'fetches a metadata' do
      expect(db.get_schedule_metadata('key')).to be_an_instance_of(ScheduleWithMetadata)
    end
    it 'raises error if non exist key' do
      expect{db.get_schedule_metadata('nonexistent')}.to raise_error(NotFoundError)
    end
  end

  context '#list' do
    before do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
    end
    it 'lists a metadata' do
      db.list(nil) do |x|
        expect(x).to be_an_instance_of(PerfectSched::ScheduleWithMetadata)
        expect(x.key).to eq('key')
      end
    end
  end

  context '#add' do
    it 'adds schedules' do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
      expect{db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})}.to raise_error(IdempotentAlreadyExistsError)
    end
  end

  context '#delete' do
    before do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
    end
    it 'deletes schedules' do
      db.delete('key', nil)
      expect{db.delete('key', nil)}.to raise_error(IdempotentNotFoundError)
    end
  end

  context '#modify' do
    before do
      db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
    end
    it 'returns nil if no keys' do
      expect(db.modify('key', {})).to be_nil
    end
    it 'modifies schedules' do
      db.modify('key', {delay: 1})
    end
    it 'raises if nonexistent' do
      expect{db.modify('nonexistent', {delay: 0})}.to raise_error(NotFoundError)
    end
  end

  context '#acquire' do
    context 'no tasks' do
      it 'returns nil' do
        expect(db.acquire(0, nil, {})).to be_nil
      end
    end
    context 'some tasks' do
      before do
        db.add('key1', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
      end
      it 'returns a task' do
        ary = db.acquire(0, nil, {})
        expect(ary).to be_an_instance_of(Array)
        expect(ary[0]).to be_an_instance_of(Task)
      end
    end
    context 'some tasks but conflict with another process' do
      before do
        db.add('key1', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
        db.add('key2', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
        db.add('key3', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, now, now, {})
      end
      it 'returns nil' do
        data_set = double('data_set', update: 0)
        allow(db.db).to receive(:[]).and_return(data_set)
        expect(db.acquire(0, nil, {})).to be_nil
      end
    end
  end

  context '#heartbeat' do
    let (:next_time){ now }
    let (:task_token){ Backend::RDBCompatBackend::Token.new('key', next_time, '* * * * *', 0, 'Asia/Tokyo') }
    context 'have a scheduled task' do
      before do
        db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, next_time, next_time, {})
      end
      it 'returns nil if next_run_time is not updated' do
        expect(db.heartbeat(task_token, 0, {now: next_time})).to be_nil
      end
      it 'returns nil even if next_run_time is updated' do
        expect(db.heartbeat(task_token, 1, {})).to be_nil
      end
    end
    context 'no tasks' do
      it 'raises PreemptedError' do
        expect{db.heartbeat(task_token, 0, {})}.to raise_error(PreemptedError)
      end
    end
  end

  context '#finish' do
    let (:next_time){ now }
    let (:task_token){ Backend::RDBCompatBackend::Token.new('key', next_time, '* * * * *', 0, 'Asia/Tokyo') }
    context 'have the task' do
      before do
        db.add('key', 'test', '* * * * *', 0, 'Asia/Tokyo', {}, next_time, next_time, {})
      end
      it 'returns nil' do
        expect(db.finish(task_token, nil)).to be_nil
      end
    end
    context 'already finished' do
      it 'raises IdempotentAlreadyFinishedError' do
        expect{db.finish(task_token, nil)}.to raise_error(IdempotentAlreadyFinishedError)
      end
    end
  end

  context '#connect' do
    context 'normal' do
      let (:ret){ double('ret') }
      it 'returns block result' do
        expect(db.__send__(:connect){ ret }).to eq(ret)
      end
    end
    context 'error' do
      it 'returns block result' do
        expect(RuntimeError).to receive(:new).exactly(Backend::RDBCompatBackend::MAX_RETRY).and_call_original
        allow(STDERR).to receive(:puts)
        allow(db).to receive(:sleep)
        expect do
          db.__send__(:connect) do
            raise RuntimeError.new('try restarting transaction')
          end
        end.to raise_error(RuntimeError)
      end
    end
  end

  context '#create_attributes' do
    let (:data){ Hash.new }
    let (:row) do
      r = double('row')
      allow(r).to receive(:[]){|k| data[k] }
      r
    end
    it 'returns a hash consisting the data of the row' do
      data[:timezone] = timezone = double('timezone')
      data[:delay] = delay = double('delay')
      data[:cron] = cron = double('cron')
      data[:next_time] = next_time = double('next_time')
      data[:timeout] = timeout = double('timeout')
      data[:data] = '{"type":"foo.bar","a":"b"}'
      data[:id] = 'hoge'
      expect(db.__send__(:create_attributes, row)).to eq(
        timezone: timezone,
        delay: delay,
        cron: cron,
        data: {"a"=>"b"},
        next_time: next_time,
        next_run_time: timeout,
        type: 'foo.bar',
        message: nil,
        node: nil,
      )
    end
    it 'returns {} if data\'s JSON is broken' do
      data[:data] = '}{'
      data[:id] = 'foo.bar.baz'
      expect(db.__send__(:create_attributes, row)).to eq(
        timezone: 'UTC',
        delay: 0,
        cron: nil,
        data: {},
        next_time: nil,
        next_run_time: nil,
        type: 'foo',
        message: nil,
        node: nil,
      )
    end
    it 'uses id[/\A[^.]*/] if type is empty string' do
      data[:data] = '{"type":""}'
      data[:id] = 'foo.bar.baz'
      expect(db.__send__(:create_attributes, row)).to eq(
        timezone: 'UTC',
        delay: 0,
        cron: nil,
        data: {},
        next_time: nil,
        next_run_time: nil,
        type: 'foo',
        message: nil,
        node: nil,
      )
    end
    it 'uses id[/\A[^.]*/] if type is nil' do
      data[:id] = 'foo.bar.baz'
      expect(db.__send__(:create_attributes, row)).to eq(
        timezone: 'UTC',
        delay: 0,
        cron: nil,
        data: {},
        next_time: nil,
        next_run_time: nil,
        type: 'foo',
        message: nil,
        node: nil,
      )
    end
  end
end

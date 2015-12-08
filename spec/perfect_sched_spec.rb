require 'spec_helper'

describe PerfectSched do
  describe '.open' do
    let (:config){ double('config') }
    let (:client){ double('client') }
    let (:schedule_collection){ double('schedule_collection') }
    before do
      expect(Client).to receive(:new).with(config).and_return(client)
      expect(ScheduleCollection).to receive(:new).with(client).and_return(schedule_collection)
    end
    it 'returns an instance without block' do
      expect(client).not_to receive(:close)
      expect(PerfectSched.open(config)).to eq(schedule_collection)
    end
    it 'yields block if given' do
      ret = double('ret')
      expect(client).to receive(:close)
      r = PerfectSched.open(config) do |sc|
        expect(sc).to eq(schedule_collection)
        ret
      end
      expect(r).to eq(ret)
    end
  end

  describe '.cron_time' do
    it do
      ts = PerfectSched.cron_time('0 * * * *', 1, nil)
      expect(ts).to eq 3600
    end
    it do
      expect{PerfectSched.cron_time('0 * * * *', 0, 'JST-9')}.to raise_error(ArgumentError)
    end
    it do
      ts = PerfectSched.cron_time('0,30 * * * *', 1, nil)
      expect(ts).to eq 1800
    end
    it do
      ts = PerfectSched.cron_time('*/7 * * * *', 1, nil)
      expect(ts).to eq 420
    end
    it 'supports @hourly' do
      ts = PerfectSched.cron_time('@hourly', 1, nil)
      expect(ts).to eq 3600
    end
    it 'supports @daily' do
      ts = PerfectSched.cron_time('@daily', 1, nil)
      expect(ts).to eq 86400
    end
    it 'supports @monthly' do
      ts = PerfectSched.cron_time('@monthly', 1, nil)
      expect(ts).to eq 2678400
    end
  end

  describe '.next_time' do
    it 'can run hourly cron' do
      ts = PerfectSched.next_time(' 0 * * * * ', 0, nil)
      expect(ts).to eq 3600
    end
    it 'calculates 4 years quickly' do
      t = Time.utc(2012,2,29)
      ts = PerfectSched.next_time('0 0 29 2 *', t.to_i, nil)
      expect(ts).to eq(Time.utc(2016,2,29).to_i)
    end
    it 'raises error on unsupported timezone' do
      expect{PerfectSched.next_time('0 * * * *', 0, 'JST-9')}.to raise_error(ArgumentError)
    end
    it 'returns next run time of given time' do
      t0 = Time.new(2015, 12,  3,  1,  0,  0,  9*3600)
      t1 = Time.new(2015, 12,  3,  2,  0,  0,  9*3600)
      ts = PerfectSched.next_time('0 * * * *', t0.to_i, 'Asia/Tokyo')
      expect(ts).to eq(t1.to_i)
    end
    it 'returns next run time of given time' do
      t0 = Time.new(2015, 12,  3,  1, 59, 59,  9*3600)
      t1 = Time.new(2015, 12,  3,  2,  0,  0,  9*3600)
      ts = PerfectSched.next_time('0 * * * *', t0.to_i, 'Asia/Tokyo')
      expect(ts).to eq(t1.to_i)
    end
    it 'returns next run time with day of week (0=Sun)' do
      t0 = Time.new(2015, 12,  3,  0,  0,  0,  9*3600)
      t1 = Time.new(2015, 12,  6,  0,  0,  0,  9*3600)
      ts = PerfectSched.next_time('0 0 * * 0', t0.to_i, 'Asia/Tokyo')
      expect(ts).to eq(t1.to_i)
    end
    context 'DST 2015' do
      it 'skips task on 8 Mar because 1:59:59 PST -> 3:00:00 PDT' do
        t0 = Time.new(2015,  3,  7,  2,  0,  0, -8*3600)
        # 2015-03-08T02:00:00 doesn't exist
        t1 = Time.new(2015,  3,  9,  2,  0,  0, -7*3600)
        ts = PerfectSched.next_time('0 2 * * *', t0.to_i, 'America/Los_Angeles')
        expect(ts).to eq(t1.to_i)
      end
      it 'runs twice on Nov 11 because 1:59:59 PDT -> 1:00:00 PST' do
        # 2015-11-01T01:00:00 exists twice
        t0 = Time.new(2015, 11,  1,  1,  0,  0, -7*3600)
        t1 = Time.new(2015, 11,  1,  1,  0,  0, -8*3600)
        ts = PerfectSched.next_time('0 1 * * *', t0.to_i, 'America/Los_Angeles')
        expect(ts).to eq(t1.to_i)
      end
    end
  end
end

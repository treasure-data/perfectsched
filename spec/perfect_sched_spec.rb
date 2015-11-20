require 'spec_helper'

describe PerfectSched do
  context '.open' do
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

  context 'cron_time' do
    it do
      ts = PerfectSched.cron_time('0 * * * *', 0, nil)
      expect(ts).not_to be_nil
    end
    it do
      expect{PerfectSched.cron_time('0 * * * *', 0, 'JST-9')}.to raise_error(ArgumentError)
    end
  end

  context '.next_time' do
    it do
      ts = PerfectSched.next_time('0 * * * *', 0, nil)
      expect(ts).not_to be_nil
    end
    xit 'calculates 4 years quickly' do
      t = Time.utc(2012,2,29)
      ts = PerfectSched.next_time('0 0 29 2 *', t.to_i, nil)
      expect(ts).to eq(Time.utc(2016,2,29).to_i)
    end
    it do
      expect{PerfectSched.next_time('0 * * * *', 0, 'JST-9')}.to raise_error(ArgumentError)
    end
  end
end

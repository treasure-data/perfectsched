require 'spec_helper'

describe PerfectSched::Model do
  let (:config){ double('config') }
  let (:client){ double('client', config: config) }
  let (:klass){ Class.new{include PerfectSched::Model} }
  let (:model){ klass.new(client) }
  describe '.new' do
    it 'creates an instance' do
      expect(model).to be_a(PerfectSched::Model)
      expect(model.instance_variable_get(:@client)).to eq(client)
    end
  end
  describe '#client' do
    it 'returns its client' do
      expect(model.client).to eq(client)
    end
  end
  describe '#config' do
    it 'returns its client.config' do
      expect(model.config).to eq(client.config)
    end
  end
end

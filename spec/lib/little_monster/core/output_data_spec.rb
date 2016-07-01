require 'spec_helper'

describe LittleMonster::Core::OutputData do
  let(:job) { double(current_task: 'a_task') }
  let(:output_data) { LittleMonster::Core::OutputData.new(job) }

  describe '#initialize' do
    it 'sets appropiate variables' do
      expect(output_data.instance_variable_get '@outputs').to eq({})
      expect(output_data.instance_variable_get('@key_owners')).to eq({})
      expect(output_data.instance_variable_get('@job')).to eq(job)
    end
  end

  describe '#[]=' do
    it 'raises KeyError if key already exists' do
      output_data['some_key'] = 'value'
      expect{ output_data['some_key'] = 'othet value' }.to raise_error(KeyError)
    end

    it 'sets the key value if non exiting' do
      output_data[:some_key] = 'value'
      expect(output_data.instance_variable_get('@outputs')[:some_key]).to  eq('value')
    end

    it 'appends the task name and key to key_owners' do
      output_data[:some_key] = 'value'
      expect(output_data.instance_variable_get('@key_owners')[:a_task]).to  include(:some_key)
    end
  end

  describe '#[]' do
    it 'returns the appropiate value if requested' do
      output_data[:some_key] = 'value'
      expect(output_data['some_key']).to eq('value')
    end

    it 'returns nil if key has no value' do
      expect(output_data['some_key']).to be_nil
    end
  end

  describe '#==' do
    it 'returns false if type differs'
    it 'returns true if @outputs is equal'
    it 'returns false if @outputs differs'
  end

  describe '#to_json' do
    let(:json_data) { {'outputs' => { 'key' => 'value', 'lol' => 'some', 'keys' => 'nul' }, 'owners' => { 'a_task' => ['key', 'lol'], 'b_task' => ['keys'] } } }

    it 'returns each key owner and each output' do
      allow(job).to receive(:current_task).and_return(:a_task)
      output_data[:key] = 'value'
      output_data[:lol] = 'some'
      allow(job).to receive(:current_task).and_return(:b_task)
      output_data[:keys] = 'nul'

      expect(MultiJson.load(output_data.to_json)).to eq(json_data)
    end

    it 'returns empty if no data entered' do
      expect(output_data.to_json).to eq('{}')
    end
  end
end

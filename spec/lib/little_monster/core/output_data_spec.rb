require 'spec_helper'

describe LittleMonster::Core::OutputData do
  let(:output_data) { LittleMonster::Core::OutputData.new }

  describe '#initialize' do
    it 'sets appropiate variables' do
      expect(output_data.instance_variable_get '@outputs').to eq({})
      expect(output_data.instance_variable_get('@key_owners')).to eq({})
    end
  end

  describe '#give_to' do
    it 'returns self' do
      expect(output_data.give_to(:a_task)).to eq(output_data)
    end

    it 'sets the task as current_task' do
      output_data.give_to(:a_task)
      expect(output_data.instance_variable_get '@current_task').to eq(:a_task)
    end

    it 'initializes key_owners for the given task' do
      output_data.give_to(:a_task)
      expect(output_data.instance_variable_get('@key_owners')[:a_task]).to eq([])
    end
  end

  describe '#[]=' do
    before :each do
      @od = output_data.give_to(:a_task)
    end

    it 'raises KeyError if key already exists' do
      @od['some_key'] = 'value'
      expect{ @od['some_key'] = 'othet value' }.to raise_error(KeyError)
    end

    it 'sets the key value if non exiting' do
      @od[:some_key] = 'value'
      expect(@od.instance_variable_get('@outputs')[:some_key]).to  eq('value')
    end

    it 'appends the task name and key to key_owners' do
      @od[:some_key] = 'value'
      expect(@od.instance_variable_get('@key_owners')[:a_task]).to  include(:some_key)
    end
  end

  describe '#[]' do
    before :each do
      @od = output_data.give_to(:a_task)
    end

    it 'returns the appropiate value if requested' do
      @od[:some_key] = 'value'
      expect(@od['some_key']).to eq('value')
    end

    it 'returns nil if key has no value' do
      expect(@od['some_key']).to be_nil
    end
  end

  describe '#to_json' do
    let(:json_data) { {'outputs' => { 'key' => 'value', 'lol' => 'some', 'keys' => 'nul' }, 'owners' => { 'a_task' => ['key', 'lol'], 'b_task' => ['keys'] } } }

    it 'returns each key owner and each output' do
      od = output_data.give_to(:a_task)
      od[:key] = 'value'
      od[:lol] = 'some'
      od = output_data.give_to(:b_task)
      od[:keys] = 'nul'

      expect(MultiJson.load(output_data.to_json)).to eq(json_data)
    end

    it 'returns empty if no data entered' do
      expect(output_data.to_json).to eq('{}')
    end
  end
end

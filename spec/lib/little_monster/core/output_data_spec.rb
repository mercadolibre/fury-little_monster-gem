require 'spec_helper'

describe LittleMonster::Core::OutputData do
  describe '#initialize' do
    it 'sets appropiate variables'
  end

  describe '#give_to' do
    it 'returns self'
    it 'sets the task as current_task'
    it 'initializes key_owners for the given task'
  end

  describe '#[]' do
    it 'returns the appropiate value if requested'
    it 'returns nil if key has no value'
  end

  describe '#[]=' do
    it 'raises KeyError if key already exists'
    it 'sets the key value if non exiting'
    it 'appends the task name and key to key_owners'
  end

  describe '#to_json' do
    it 'returns each key owner and each output'
    it 'returns empty if no data entered'
  end
end

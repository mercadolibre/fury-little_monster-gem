require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveData do
  let(:job) { double(current_task: 'a_task') }
  let(:data) { LittleMonster::Core::Job::Data.new(job) }
  subject { described_class.new data }

  it_behaves_like 'matcher'

  describe '#initialize' do
    it 'sets the expected_data' do
      expect(subject.instance_variable_get('@expected_data')).to eq(data)
    end
  end

  describe '#matches?' do
    context 'given a job_result' do
      it 'returns true if data matches' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     data: data)
        expect(subject.matches? job_result).to be true
      end

      it 'returns false if data does not match the expected' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     data: {})
        expect(subject.matches? job_result).to be false
      end
    end
  end

  describe 'failure_message' do
    before :each do
      subject.instance_variable_set('@actual_data', {})
    end

    specify do
      expect(subject.failure_message).to eq("expected data #{data} but was nil")
    end
  end

  describe 'failure_message_when_negated' do
    specify do
      expect(subject.failure_message_when_negated).to eq("expected data not to be #{data}")
    end
  end
end

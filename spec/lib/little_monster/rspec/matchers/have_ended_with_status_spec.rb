require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveEndedWithStatus do
  subject { described_class.new :status }

  it_behaves_like 'matcher'

  describe '#initialize' do
    it 'sets the expected_status' do
      expect(subject.instance_variable_get('@expected_status')).to eq(:status)
    end
  end

  describe '#matches?' do
    context 'given a job_result' do
      it 'returns true if status matches' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     status: :status)
        expect(subject.matches? job_result).to be true
      end

      it 'returns false if status does not matches' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     status: :another_status)
        expect(subject.matches? job_result).to be false
      end
    end
  end

  describe 'failure_message' do
    before :each do
      subject.instance_variable_set('@actual_status', :another_status)
    end

    specify do
      expect(subject.failure_message).to eq("expected job to end with status status " \
                                            "but was another_status")
    end
  end

  describe 'failure_message_when_negated' do
    specify do
      expect(subject.failure_message_when_negated).to eq("expected job not to end with status status " \
                                                         "but instead ended that way")
    end
  end
end

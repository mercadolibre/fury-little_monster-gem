require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveRetries do
  let(:expected_retries) { 5 }
  subject { described_class.new expected_retries }

  it_behaves_like 'matcher'

  describe '#initialize' do
    it 'sets the expected_retries' do
      expect(subject.instance_variable_get('@expected_retries')).to eq(expected_retries)
    end
  end

  describe '#matches?' do
    context 'given a job_class' do
      it 'returns true if job has the expected retries' do
        job_class = double(max_retries: expected_retries, class: Class)
        allow(job_class).to receive(:instance_of?).and_return(true)
        expect(subject.matches? job_class).to be true
      end

      it 'returns false if job does not have the expected retries' do
        job_class = double(max_retries: expected_retries+1, class: Class)
        allow(job_class).to receive(:instance_of?).and_return(true)
        expect(subject.matches? job_class).to be false
      end
    end
  end

  describe 'failure_message' do
    before :each do
      subject.instance_variable_set('@actual_retries', expected_retries+1)
    end

    specify do
      expect(subject.failure_message).to eq("expected job to have retries #{expected_retries} " \
                                            "but has #{expected_retries+1}")
    end
  end

  describe 'failure_message_when_negated' do
    specify do
      expect(subject.failure_message_when_negated).to eq("expected job not to have retries #{expected_retries} " \
                                                         "but it does")
    end
  end
end

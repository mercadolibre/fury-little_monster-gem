require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveOutput do
  let(:output) { { a: :b } }
  subject { described_class.new output }

  it_behaves_like 'matcher'

  describe '#initialize' do
    it 'sets the expected_output' do
      expect(subject.instance_variable_get('@expected_output')).to eq(output)
    end
  end

  describe '#matches?' do
    context 'given a job_result' do
      it 'returns true if output matches' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     output: output)
        expect(subject.matches? job_result).to be true
      end

      it 'returns false if output does not match the expected' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     output: {})
        expect(subject.matches? job_result).to be false
      end
    end
  end

  describe 'failure_message' do
    before :each do
      subject.instance_variable_set('@actual_output', {})
    end

    specify do
      expect(subject.failure_message).to eq("expected output #{output} but was {}")
    end
  end

  describe 'failure_message_when_negated' do
    specify do
      expect(subject.failure_message_when_negated).to eq("expected output not to be #{output}")
    end
  end
end

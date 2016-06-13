require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveRun do
  let(:tasks) { [:a, :b, :c] }
  subject { LittleMonster::RSpec::Matchers::HaveRun.new tasks }

  it_behaves_like 'matcher'

  describe '#initialize' do
    subject { LittleMonster::RSpec::Matchers::HaveRun }

    context 'given multiple tasks' do
      it 'sets the expected_tasks' do
        matcher = subject.new(*tasks)
        expect(matcher.instance_variable_get '@expected_tasks').to eq(tasks)
      end
    end

    context 'given an array of tasks' do
      it 'sets the expected_tasks' do
        matcher = subject.new(tasks)
        expect(matcher.instance_variable_get '@expected_tasks').to eq(tasks)
      end
    end
  end

  describe '#matches?' do
    context 'given a job_result' do
      it 'returns true if runneds_tasks match expected_tasks' do
        runned_tasks = Hash[tasks.map { |t| [t, double] }]
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     runned_tasks: runned_tasks)
        expect(subject.matches? job_result).to be true
      end

      it 'returns false if runneds_tasks do not match the expected_tasks' do
        job_result = instance_double(LittleMonster::RSpec::JobHelper::Result,
                                     runned_tasks: { a: double })
        expect(subject.matches? job_result).to be false
      end
    end
  end

  describe 'failure_message' do
    before :each do
      subject.instance_variable_set('@actual_tasks',[])
    end

    specify do
      expect(subject.failure_message).to eq("expected job to run #{tasks} " \
                                            "but instead run []")
    end
  end

  describe 'failure_message_when_negated' do
    specify do
      expect(subject.failure_message_when_negated).to eq("expected job not to run #{tasks}")
    end
  end
end

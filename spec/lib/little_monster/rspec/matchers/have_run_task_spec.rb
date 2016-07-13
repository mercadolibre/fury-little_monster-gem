require 'spec_helper'
require_relative './shared_examples/matcher'

describe LittleMonster::RSpec::Matchers::HaveRunTask do
  let(:expected_task) { :task }
  subject { LittleMonster::RSpec::Matchers::HaveRunTask.new expected_task }

  it_behaves_like 'matcher'

  describe '#initialize' do
    subject { LittleMonster::RSpec::Matchers::HaveRunTask }

    context 'given a class' do
      it 'sets the expected_task to the leaf constant' do
        matcher = subject.new MockJob::Task
        expect(matcher.expected_task).to eq(expected_task)
      end
    end

    context 'given a symbol' do
      it 'sets the expected_tasks' do
        matcher = subject.new(expected_task)
        expect(matcher.expected_task).to eq(expected_task)
      end
    end
  end

  describe '#matches?' do
    context 'given a job_result' do
      let(:task) { double }
      let(:task_data) { {} }
      let(:job_result) do
        instance_double(LittleMonster::RSpec::JobHelper::Result,
                        runned_tasks: { expected_task => { instance: task, data: task_data } })
      end

      before :each do
        allow(subject).to receive(:check_task_run).and_return(true)
        allow(subject).to receive(:check_data).and_return(true)
      end

      it 'sets the task instance variable from the job runned_tasks[instance] key' do
        subject.matches?(job_result)
        expect(subject.instance_variable_get '@task').to eq(task)
      end

      it 'sets the task data instance variable from the job runned_tasks[data] key' do
        subject.matches?(job_result)
        expect(subject.instance_variable_get '@task_data').to eq(task_data)
      end

      it 'returns true if alls checks pass' do
        expect(subject.matches? job_result).to be true
      end

      context 'returns false when' do
        it 'fails checking task' do
          allow(subject).to receive(:check_task_run).and_return(false)
        end

        it 'fails checking data' do
          allow(subject).to receive(:check_data).and_return(false)
        end

        after :each do
          expect(subject.matches? job_result).to be false
        end
      end
    end
  end

  describe 'with_data' do
    let(:data) { double }

    it 'sets expected_data' do
      subject.with_data data
      expect(subject.expected_data).to eq(data)
    end

    it 'returns self' do
      expect(subject.with_data data).to eq(subject)
    end
  end

  describe '#check_task_run' do
    it 'returns true if task is not nil' do
      subject.instance_variable_set '@task', double
      expect(subject.check_task_run).to be true
    end

    it 'returns false if task is nil' do
      expect(subject.check_task_run).to be false
    end
  end

  describe '#check_data' do
    context 'when expected_data is defined' do
      let(:expected_data) { { a: :b } }
      before :each do
        subject.instance_variable_set '@expected_data', expected_data
      end

      it 'returns true if task data match expected data' do
        subject.instance_variable_set '@task_data', expected_data
        expect(subject.check_data).to be true
      end

      it 'returns false if task data dont match expected data' do
        subject.instance_variable_set '@task_data', {}
        expect(subject.check_data).to be false
      end
    end

    context 'when expected_data is not defined' do
      it 'returns true' do
        expect(subject.check_data).to be true
      end
    end
  end

  describe 'failure_message' do
    before :each do
      allow(subject).to receive(:check_task_run).and_return(true)
      allow(subject).to receive(:check_data).and_return(true)
    end

    specify do
      expect(subject.failure_message).to include("task #{expected_task} was expected to run\n")
    end

    context 'when check data failed' do
      let(:expected_data) { { a: :b } }
      let(:actual_data) { { b: :c } }

      before :each do
        allow(subject).to receive(:check_data).and_return(false)
        subject.instance_variable_set '@expected_data', expected_data
        subject.instance_variable_set '@task_data', actual_data
      end

      specify do
        expect(subject.failure_message).to include("\twith data #{expected_data} but was #{actual_data}\n")
      end
    end
  end
end

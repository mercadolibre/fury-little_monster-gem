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
      let(:task_output) { {} }
      let(:job_result) do
        instance_double(LittleMonster::RSpec::JobHelper::Result,
                        runned_tasks: { expected_task => { instance: task, output: task_output } })
      end

      before :each do
        allow(subject).to receive(:check_task_run).and_return(true)
        allow(subject).to receive(:check_params).and_return(true)
        allow(subject).to receive(:check_previous_output).and_return(true)
        allow(subject).to receive(:check_output).and_return(true)
      end

      it 'sets the task instance variable from the job runned_tasks[instance] key' do
        subject.matches?(job_result)
        expect(subject.instance_variable_get '@task').to eq(task)
      end

      it 'sets the task output instance variable from the job runned_tasks[output] key' do
        subject.matches?(job_result)
        expect(subject.instance_variable_get '@task_output').to eq(task_output)
      end

      it 'returns true if alls checks pass' do
        expect(subject.matches? job_result).to be true
      end

      context 'returns false when' do
        it 'fails checking task' do
          allow(subject).to receive(:check_task_run).and_return(false)
        end

        it 'fails checking params' do
          allow(subject).to receive(:check_params).and_return(false)
        end

        it 'fails checking previous_output' do
          allow(subject).to receive(:check_previous_output).and_return(false)
        end

        it 'fails checking output' do
          allow(subject).to receive(:check_output).and_return(false)
        end

        after :each do
          expect(subject.matches? job_result).to be false
        end
      end
    end
  end

  describe 'with_params' do
    let(:params) { double }

    it 'sets expected_params' do
      subject.with_params params
      expect(subject.expected_params).to eq(params)
    end

    it 'returns self' do
      expect(subject.with_params params).to eq(subject)
    end
  end


  describe 'with_previous_output' do
    let(:previous_output) { double }

    it 'sets expected_previous_output' do
      subject.with_previous_output previous_output
      expect(subject.expected_previous_output).to eq(previous_output)
    end

    it 'returns self' do
      expect(subject.with_previous_output previous_output).to eq(subject)
    end
  end

  describe 'with_output' do
    let(:output) { double }

    it 'sets expected_output' do
      subject.with_output output
      expect(subject.expected_output).to eq(output)
    end

    it 'returns self' do
      expect(subject.with_output output).to eq(subject)
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

  describe '#check_params' do
    context 'when expected_params is defined' do
      let(:expected_params) { { a: :b } }
      before :each do
        subject.instance_variable_set '@expected_params', expected_params
      end

      it 'returns true if task params match expected params' do
        task = double(params: expected_params)
        subject.instance_variable_set '@task', task
        expect(subject.check_params).to be true
      end

      it 'returns false if task params dont match expected params' do
        task = double(params: {})
        subject.instance_variable_set '@task', task
        expect(subject.check_params).to be false
      end
    end

    context 'when expected_params is not defined' do
      it 'returns true' do
        expect(subject.check_params).to be true
      end
    end
  end

  describe '#check_previous_output' do
    context 'when expected_previous_output is defined' do
      let(:expected_previous_output) { { a: :b } }
      before :each do
        subject.instance_variable_set '@expected_previous_output', expected_previous_output
      end

      it 'returns true if task previous_output match expected previous_output' do
        task = double(previous_output: expected_previous_output)
        subject.instance_variable_set '@task', task
        expect(subject.check_previous_output).to be true
      end

      it 'returns false if task previous_output dont match expected previous_output' do
        task = double(previous_output: {})
        subject.instance_variable_set '@task', task
        expect(subject.check_previous_output).to be false
      end
    end

    context 'when expected_previous_output is not defined' do
      it 'returns true' do
        expect(subject.check_previous_output).to be true
      end
    end
  end

  describe '#check_output' do
    context 'when expected_output is defined' do
      let(:expected_output) { { a: :b } }
      before :each do
        subject.instance_variable_set '@expected_output', expected_output
      end

      it 'returns true if task output match expected output' do
        subject.instance_variable_set '@task_output', expected_output
        expect(subject.check_output).to be true
      end

      it 'returns false if task output dont match expected output' do
        subject.instance_variable_set '@task_output', {}
        expect(subject.check_output).to be false
      end
    end

    context 'when expected_output is not defined' do
      it 'returns true' do
        expect(subject.check_output).to be true
      end
    end
  end

  describe 'failure_message' do
    before :each do
      allow(subject).to receive(:check_task_run).and_return(true)
      allow(subject).to receive(:check_params).and_return(true)
      allow(subject).to receive(:check_previous_output).and_return(true)
      allow(subject).to receive(:check_output).and_return(true)
    end

    specify do
      expect(subject.failure_message).to include("task #{expected_task} was expected to run\n")
    end

    context 'when check params failed' do
      let(:expected_params) { { a: :b } }
      let(:actual_params) { { b: :c } }

      before :each do
        allow(subject).to receive(:check_params).and_return(false)
        subject.instance_variable_set '@expected_params', expected_params
        subject.instance_variable_set '@task', double(params: actual_params)
      end

      specify do
        expect(subject.failure_message).to include("\twith params #{expected_params} but received #{actual_params}\n")
      end
    end

    context 'when check previous_output failed' do
      let(:expected_previous_output) { { a: :b } }
      let(:actual_previous_output) { { b: :c } }

      before :each do
        allow(subject).to receive(:check_previous_output).and_return(false)
        subject.instance_variable_set '@expected_previous_output', expected_previous_output
        subject.instance_variable_set '@task', double(previous_output: actual_previous_output)
      end

      specify do
        expect(subject.failure_message).to include("\twith previous_output #{expected_previous_output} but received #{actual_previous_output}\n")
      end
    end

    context 'when check output failed' do
      let(:expected_output) { { a: :b } }
      let(:actual_output) { { b: :c } }

      before :each do
        allow(subject).to receive(:check_output).and_return(false)
        subject.instance_variable_set '@expected_output', expected_output
        subject.instance_variable_set '@task', double(output: actual_output)
      end

      specify do
        expect(subject.failure_message).to include("\twith output #{expected_output} but outputed #{actual_output}\n")
      end
    end
  end
end

require 'spec_helper'

describe LittleMonster::Core::Runner do
  describe '#initialize' do
    context 'given a class' do
      it 'sets the job_class variable' do
        job_class = MockJob
        expect(described_class.new(job_class).job_class).to eq(job_class)
      end
    end

    context 'given a symbol' do
      it 'sets the job_class variable to the corresponding class' do
        job_class = :mock_job
        expect(described_class.new(job_class).job_class).to eq(MockJob)
      end

      context 'when there is no corresponding class' do
        it 'raises a JobNotFoundError' do
          job_class = :non_existing
          expect { described_class.new(job_class) }.to raise_error(LittleMonster::JobNotFoundError, "no job found for non_existing")
        end
      end
    end

    it 'sets the params variable' do
      params = { a: :b }
      expect(described_class.new(:mock_job, params).params).to eq(params)
    end
  end

  describe '#run' do
    let(:params) { { a: :b } }
    let(:mock_job) { double(run: :run_output) }
    let(:runner) { described_class.new(:mock_job, params) }

    before :each do
      allow(MockJob).to receive(:new).and_return(mock_job)
      runner.run
    end

    it 'creates a job instance with params' do
      expect(MockJob).to have_received(:new).with(params)
    end

    it 'runs the job' do
      expect(mock_job).to have_received(:run)
    end

    it 'returns the job output' do
      expect(runner.run).to eq(:run_output)
    end
  end
end

require 'spec_helper'

describe LittleMonster::Worker do
  let(:message) do
    {
      params: '{}',
      name: 'mock_job'
    }
  end

  let(:worker) { described_class.new }
  let(:job) { double(run: nil) }
  let(:factory) { double(build: job) }

  describe '#perform' do
    before :each do
      allow(LittleMonster::Job::Factory).to receive(:new).and_return(factory)
    end

    it 'calls on_message' do
      allow(worker).to receive(:on_message)
      worker.perform(nil, 'Message' => MultiJson.dump(message))
      expect(worker).to have_received(:on_message).once
    end

    it 'builds job instance from factory' do
      worker.perform(nil, 'Message' => MultiJson.dump(message))
      expect(factory).to have_received(:build).once
    end

    it 'runs job if it is not nil' do
      worker.perform(nil, 'Message' => MultiJson.dump(message))
      expect(job).to have_received(:run).once
    end

    it 'does not run job if it is nil' do
      allow(factory).to receive(:build).and_return(nil)
      worker.perform(nil, 'Message' => MultiJson.dump(message))
      expect(job).not_to have_received(:run)
    end
  end

  describe '::worker_queue' do
    it 'sets toiler queue' do
      queue = double
      allow(described_class).to receive(:toiler_options)
      described_class.worker_queue queue
      expect(described_class).to have_received(:toiler_options).with(queue: queue).once
    end
  end

  describe '::worker_concurrency' do
    it 'sets toiler concurrency' do
      concurrency = double
      allow(described_class).to receive(:toiler_options)
      described_class.worker_concurrency concurrency
      expect(described_class).to have_received(:toiler_options).with(concurrency: concurrency).once
    end
  end
end

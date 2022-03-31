require 'spec_helper'

describe LittleMonster::Worker do
  let(:message) do
    {
      data: {},
      name: 'mock_job'
    }
  end

  let(:worker) { described_class.new }

  describe '::update_attributes' do
    it 'calls toiler options with queue and concurrency' do
      allow(described_class).to receive(:toiler_options)
      described_class.update_attributes
      expect(described_class).to have_received(:toiler_options).with(queue: LittleMonster.worker_queue,
                                                                     concurrency: LittleMonster.worker_concurrency,
                                                                     provider: LittleMonster.worker_provider,
                                                                     provider_config: LittleMonster.worker_provider_config)
    end
  end

  describe '#perform' do
    let(:runner) { double(run: nil) }

    before :each do
      allow(LittleMonster::Core::Runner).to receive(:new).and_return(runner)
      worker.perform(nil, 'Message' => MultiJson.dump(message))
    end

    it 'creates a runner instance with parsed message and parsed data' do
      expect(LittleMonster::Core::Runner).to have_received(:new).with(message)
    end

    it 'calls run on runner' do
      expect(runner).to have_received(:run)
    end
  end
end

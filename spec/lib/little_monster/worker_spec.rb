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
      allow(worker).to receive(:send_heartbeat!)
    end

    context 'when heartbeat raises JobAlreadyLockedError' do
      before :each do
        allow(worker).to receive(:send_heartbeat!).and_raise(LittleMonster::JobAlreadyLockedError)
      end

      it 'does not call on_message' do
        allow(worker).to receive(:on_message)
        worker.perform(nil, 'Message' => MultiJson.dump(message))
        expect(worker).not_to have_received(:on_message)
      end

      it 'does not run job' do
        worker.perform(nil, 'Message' => MultiJson.dump(message))
        expect(job).not_to have_received(:run)
      end
    end

    context ' when heartbeat passes' do
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
  end

  describe '#send_heartbeat!' do
    context 'given an id' do
      let(:id) { 1 }
      let(:response) { double(code: 200) }

      before :each do
        allow(LittleMonster::API).to receive(:put).and_return(response)
      end

      it 'makes a request to api with critical: true , ip and pid' do
        worker.send_heartbeat! id
        expect(LittleMonster::API).to have_received(:put).with("/jobs/#{id}", critical: true,
                                                          body: { worker: hash_including(:ip, :worker) })
      end

      context 'if request is unauthorized' do
        before :each do
          allow(response).to receive(:code).and_return(401)
        end

        it 'raises JobAlreadyLockedError' do
          expect { worker.send_heartbeat! id }.to raise_error(LittleMonster::JobAlreadyLockedError)
        end
      end

      context 'if request is not unauthorized' do
        it 'returns nil' do
          expect(worker.send_heartbeat! id).to be_nil
        end
      end
    end
  end
end

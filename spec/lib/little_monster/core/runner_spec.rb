require 'spec_helper'

describe LittleMonster::Core::Runner do
  let(:params) do
    {
      data: {},
      id: 0,
      name: 'mock_job'
    }
  end

  let(:runner) { described_class.new params}
  let(:job) { double(run: nil) }
  let(:factory) { double(build: job) }

  describe '#initialize' do
    context 'given a hash of params' do
      it 'sets params variable' do
        expect(runner.instance_variable_get '@params').to eq(params)
      end

      it 'sets heartbeat_task' do
        expect(runner.instance_variable_get '@heartbeat_task').to be_instance_of(Concurrent::TimerTask)
      end
    end
  end

  describe '#run' do
    before :each do
      allow(LittleMonster::Job::Factory).to receive(:new).and_return(factory)
      allow(runner).to receive(:send_heartbeat!)
    end

    context 'when heartbeat raises JobAlreadyLockedError' do
      before :each do
        allow(runner).to receive(:send_heartbeat!).and_raise(LittleMonster::JobAlreadyLockedError)
      end

      it 'does not run job' do
        runner.run
        expect(job).not_to have_received(:run)
      end
    end

    context ' when heartbeat passes' do
      it 'builds job instance from factory' do
        runner.run
        expect(factory).to have_received(:build).once
      end

      it 'runs job if it is not nil' do
        runner.run
        expect(job).to have_received(:run).once
      end

      it 'does not run job if it is nil' do
        allow(factory).to receive(:build).and_return(nil)
        runner.run
        expect(job).not_to have_received(:run)
      end
    end
  end

  describe '#send_heartbeat!' do
    context 'if requests are enabled' do
      let(:response) { double(code: 200, success?: true) }

      before :each do
        allow(LittleMonster).to receive(:disable_requests?).and_return(false)
        allow(LittleMonster::API).to receive(:put).and_return(response)
      end

      it 'makes a request to api with critical: true , ip and pid' do
        runner.send_heartbeat!
        expect(LittleMonster::API).to have_received(:put).with("/jobs/#{params[:id]}/worker",
                                                               { body: hash_including(:ip, :pid) })
      end

      context 'if request is unauthorized' do
        before :each do
          allow(response).to receive(:code).and_return(401)
        end

        it 'raises JobAlreadyLockedError' do
          expect { runner.send_heartbeat! }.to raise_error(LittleMonster::JobAlreadyLockedError)
        end
      end

      context 'if request is not unauthorized' do
        it 'returns success?' do
          expect(runner.send_heartbeat!).to eq(response.success?)
        end
      end
    end
  end
end

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
        expect { runner.run }.to raise_error(LittleMonster::JobAlreadyLockedError)
        expect(job).not_to have_received(:run)
      end
    end

    context 'when heartbeat raises JobNotFoundError' do
      before :each do
        allow(runner).to receive(:send_heartbeat!).and_raise(LittleMonster::JobNotFoundError)
      end

      it 'swallows exception and does not run job' do
        expect { runner.run }.not_to raise_error
        expect(job).not_to have_received(:run)
      end
    end

    context 'when build raises JobClassNotFoundError' do
      before :each do
        allow(LittleMonster::API).to receive(:put)
        allow(factory).to receive(:build).and_raise(LittleMonster::JobClassNotFoundError.new(1))
      end

      it 'swallows exception and does not run job' do
        expect { runner.run }.not_to raise_error
        expect(job).not_to have_received(:run)
      end
    end

    context 'when build raises JobNotFoundError' do
      before :each do
        allow(factory).to receive(:build).and_raise(LittleMonster::JobNotFoundError)
      end

      it 'swallows exception and does not run job' do
        expect { runner.run }.not_to raise_error
        expect(job).not_to have_received(:run)
      end
    end

    context 'when build raises APIUnreachableError' do
      before :each do
        allow(factory).to receive(:build).and_raise(LittleMonster::APIUnreachableError)
      end

      it 'raises' do
        expect { runner.run }.to raise_error(LittleMonster::APIUnreachableError)
        expect(job).not_to have_received(:run)
      end
    end

    context 'when run raises JobNotFoundError' do
      before :each do
        allow(job).to receive(:run).and_raise(LittleMonster::JobNotFoundError)
      end

      it 'swallows exception' do
        expect { runner.run }.not_to raise_error
      end
    end

    context 'when run raises APIUnreachableError' do
      before :each do
        allow(job).to receive(:run).and_raise(LittleMonster::APIUnreachableError)
      end

      it 'raises' do
        expect { runner.run }.to raise_error(LittleMonster::APIUnreachableError)
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
                                                               { body: hash_including(:pid, :host), timeout: 9 }, { critical: true })
      end

      context 'if request is unauthorized' do
        before :each do
          allow(response).to receive(:code).and_return(401)
        end

        it 'raises JobAlreadyLockedError' do
          expect { runner.send_heartbeat! }.to raise_error(LittleMonster::JobAlreadyLockedError)
        end
      end

      context 'if job not found' do
        before :each do
          allow(response).to receive(:code).and_return(404)
        end

        it 'raises JobNotFoundError' do
          expect { runner.send_heartbeat! }.to raise_error(LittleMonster::JobNotFoundError)
        end
      end

      context 'request is unsuccessful' do
        before :each do
          allow(response).to receive(:code).and_return(405)
          allow(response).to receive(:success?).and_return(false)
        end

        it 'raises APIUnreachableError' do
          expect { runner.send_heartbeat! }.to raise_error(LittleMonster::APIUnreachableError)
        end
      end

      context 'if request is authorized' do
        it 'returns success?' do
          expect(runner.send_heartbeat!).to eq(response.success?)
        end
      end
    end
  end
end

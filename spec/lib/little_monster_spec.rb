require 'spec_helper'

describe LittleMonster do
  it 'includes the core module' do
    expect(LittleMonster).to include(LittleMonster::Core)
  end

  specify 'default values' do
    LittleMonster.default_config_values == {
      little_monster_api_url: 'http://little_monster_api_url.com/',
      api_request_retries: 4
    }
  end

  describe 'module functions' do
    describe '::init' do
      let(:config) { instance_double LittleMonster::Config }

      before :each do
        allow(LittleMonster::Config).to receive(:new).and_return(config)
      end

      it 'sets config static variable' do
        LittleMonster.init
        expect(LittleMonster.class_variable_get('@@config')).to eq(config)
      end

      it 'builds new config with default value' do
        LittleMonster.init
        expect(LittleMonster::Config).to have_received(:new).with(LittleMonster.default_config_values)
      end

      context 'logger' do
        context 'when env is test' do
          before :each do
            ENV['RUBY_ENV'] = 'test'
          end

          it 'is set to nil' do
            LittleMonster.init
            expect(LittleMonster.logger.instance_variable_get(:@logdev).filename).to eq('/dev/null')
          end
        end

        context 'when env is not test' do
          before :each do
            ENV['RUBY_ENV'] = 'production'
          end

          it 'is set to toiler logger' do
            LittleMonster.init
            expect(LittleMonster.logger).to eq(Toiler.logger)
          end
        end

        after :each do
          ENV['RUBY_ENV'] = 'test'
          LittleMonster.init
        end
      end
    end

    describe '::configure' do
      let(:config) { LittleMonster::Config.new }

      before :each do
        LittleMonster.class_variable_set '@@config', config
      end

      it 'yields the config from the module' do
        expect { |b| LittleMonster.configure(&b) }.to yield_with_args(config)
      end

      it 'calls Worker::update_attributes' do
        allow(LittleMonster::Worker).to receive(:update_attributes)
        LittleMonster.configure {}
        expect(LittleMonster::Worker).to have_received(:update_attributes)
      end
    end

    describe '::disable_requests?' do
      it 'returns true if env is development' do
        LittleMonster.class_variable_set '@@env', 'development'
        expect(LittleMonster.disable_requests?).to be true
      end

      it 'returns true if env is test' do
        LittleMonster.class_variable_set '@@env', 'test'
        expect(LittleMonster.disable_requests?).to be true
      end

      it 'returns false if env is anything else' do
        LittleMonster.class_variable_set '@@env', 'something else'
        expect(LittleMonster.disable_requests?).to be false
      end
    end

    describe '::logger' do
      it 'returns logger' do
        expect(LittleMonster.logger).to eq(LittleMonster.class_variable_get('@@logger'))
      end
    end

    describe '::method_missing' do
      let(:config) { double }

      before :each do
        LittleMonster.class_variable_set '@@config', config
        allow(config).to receive(:mock_method).and_return(1)
      end

      context 'if config responds to that method' do
        it 'returns the value from config' do
          expect(LittleMonster.mock_method).to eq(config.mock_method)
        end
      end

      context 'if config does not respond to that method' do
        it 'raises no method error' do
          expect { LittleMonster.not_existing_method }.to raise_error(NoMethodError)
        end
      end
    end
  end
end

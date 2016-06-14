require 'spec_helper'

describe LittleMonster::Core::Loggable do
  let(:mock_class) do
    class MockClass
      include LittleMonster::Loggable
    end
  end

  let(:mock_subclass) do
    class MockSubclass < mock_class
      include LittleMonster::Loggable
    end
  end

  before :each do
    mock_class.instance_variable_set('@logger', nil)
    mock_subclass.instance_variable_set('@logger', nil)
  end

  describe 'when included' do
    it 'extends the class' do
      expect(mock_class).to be < LittleMonster::Loggable
    end
  end

  context 'when env is test' do
    it 'always returns a logger to dev null' do
      expect(mock_class.logger.instance_variable_get('@logdev').filename).to eq('/dev/null')
      expect(mock_subclass.logger.instance_variable_get('@logdev').filename).to eq('/dev/null')
    end
  end

  context  'when env is not test' do
    before :each do
      $ENV = 'development'
    end

    after :each do
      $ENV = 'test'
    end

    describe 'initialize_logger' do
      context 'given a filename and a formatter' do
        let(:file) { '/dev/null' }

        it 'builds a new logger with filename' do
          mock_class.initialize_logger file
          expect(mock_class.logger.instance_variable_get(:'@logdev').filename).to eq(file)
        end

        context 'given a formatter' do
          let(:formatter) { double }
          it 'builds a new logger with formatter' do
            mock_class.initialize_logger file, formatter
            expect(mock_class.logger.formatter).to eq(formatter)
          end
        end

        context 'when a formatter is not given' do
          let(:default_formatter) { double }

          before :each do
            allow(mock_class).to receive(:default_formatter).and_return(default_formatter)
          end

          it 'builds logger with default formatter' do
            mock_class.initialize_logger file
            expect(mock_class.logger.formatter).to eq(default_formatter)
          end
        end

      end
    end

    describe '#default_formatter' do
      context 'if default_formatter is set in config' do
        let(:formatter) { double }
        before :each do
          LittleMonster.configure do |config|
            config.default_formatter = formatter
          end
        end

        after :each do
          LittleMonster.configure do |config|
            config.default_formatter = nil
          end
        end

        it 'returns config default formatter' do
          expect(mock_class.default_formatter).to eq(formatter)
        end
      end

      context 'if default_formatter is not set in config' do
        it 'returns a proc' do
          expect(mock_class.default_formatter.class).to eq(Proc)
        end
      end
    end

    describe 'logger instance' do
      it 'is accesible from instance' do
        expect(mock_class).to respond_to(:logger)
      end

      it 'is accesible from class' do
        expect(mock_class.new).to respond_to(:logger)
      end
    end

    describe 'logger ineritance' do
      let(:file) { '/tmp/a.log' }
      let(:default_formatter) { double }
      let(:formatter) { double }

      before :each do
        allow(mock_class).to receive(:default_formatter).and_return(default_formatter)
      end

      context 'when subclass calls its logger' do
        before :each do
          mock_class.initialize_logger file, formatter
        end

        context 'when subclass logger is not defined' do
          it 'returns a logger with parent filename and default_formatter' do
            subclass_logger = mock_subclass.logger
            expect(subclass_logger.formatter).to eq(default_formatter)
            expect(subclass_logger.instance_variable_get(:'@logdev').filename).to eq(file)
          end
        end

        context 'when subclass logger is defined' do
          it 'returns its own logger' do
            mock_subclass.initialize_logger file, formatter
            subclass_logger = mock_subclass.logger
            expect(subclass_logger.formatter).to eq(formatter)
            expect(subclass_logger.instance_variable_get(:'@logdev').filename).to eq(file)
          end
        end
      end

      context 'when parent class call its logger' do
        context 'when logger is defined' do
          it 'returns its own logger' do
            mock_class.initialize_logger file, formatter
            logger = mock_class.logger
            expect(logger.formatter).to eq(formatter)
            expect(logger.instance_variable_get(:'@logdev').filename).to eq(file)
          end
        end

        context 'when logger is not definded' do
          it 'builds a default logger' do
            allow(mock_class).to receive(:initialize_logger)
            mock_class.logger
            expect(mock_class).to have_received(:initialize_logger).with(STDOUT).once
          end
        end
      end
    end
  end
end

require 'spec_helper'

describe LittleMonster::Core::Loggable do
  let(:mock_object) do
    class MockClass
      include LittleMonster::Loggable

      def raw_logger_variable
        @logger
      end
    end

    MockClass.new
  end

  context 'on included class instance' do
    describe '#logger' do
      context 'when @logger is nil' do
        before :each do
          mock_object.instance_variable_set('@logger', nil)
        end

        it 'sets @logger to a TaggedLogger' do
          mock_object.logger
          expect(mock_object.raw_logger_variable.class).to eq(LittleMonster::TaggedLogger)
        end
      end

      context 'when logger is not nil' do
        before :each do
          mock_object.instance_variable_set('@logger', double)
        end

        it 'returns @logger' do
          expect(mock_object.logger).to eq(mock_object.raw_logger_variable)
        end
      end
    end
  end
end

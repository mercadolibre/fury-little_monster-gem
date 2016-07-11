module LittleMonster::RSpec::Matchers
  class HaveData
    def initialize(expected_data)
      @expected_data = expected_data
    end

    def matches?(actual)
      @actual_data = actual.data
      @actual_data == @expected_data
    end

    def failure_message
      "expected data #{@expected_data} but was #{@actual_data.instance_variable_get('@outputs') || 'nil'}"
    end

    def failure_message_when_negated
      "expected data not to be #{@expected_data}"
    end
  end

  def have_data(*args)
    HaveData.new(*args)
  end
end

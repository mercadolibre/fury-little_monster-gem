module LittleMonster::RSpec::Matchers
  class HaveOutput
    def initialize(expected_output)
      @expected_output = expected_output
    end

    def matches?(actual)
      if actual.instance_variable_get('@job') != nil
        @actual_output = actual.instance_variable_get('@job').instance_variable_get('@output')
      else
        @actual_output = actual.output
      end
      @actual_output == @expected_output
    end

    def failure_message
      "expected output #{@expected_output} but was #{@actual_output || {}}"
    end

    def failure_message_when_negated
      "expected output not to be #{@expected_output}"
    end
  end

  def have_output(*args)
    HaveOutput.new(*args)
  end
end

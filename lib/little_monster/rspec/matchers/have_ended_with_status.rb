module LittleMonster::RSpec::Matchers
  class HaveEndedWithStatus
    def initialize(expected_status)
      @expected_status = expected_status
    end

    def matches?(job_result)
      @actual_status = job_result.status
      @actual_status == @expected_status
    end

    def failure_message
      "expected job to end with status #{@expected_status} but was #{@actual_status}"
    end

    def failure_message_when_negated
      "expected job not to end with status #{@expected_status} but instead ended that way"
    end
  end

  def have_ended_with_status(*args)
    HaveEndedWithStatus.new(*args)
  end
end

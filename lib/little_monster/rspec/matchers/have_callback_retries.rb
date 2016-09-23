module LittleMonster::RSpec::Matchers
  class HaveCallbackRetries
    def initialize(expected_retries)
      @expected_retries = expected_retries
    end

    def matches?(job_class)
      @job_class = job_class.class == Class ? job_class : job_class.to_s.camelcase.constantize
      @actual_retries = @job_class.callback_max_retries
      @actual_retries == @expected_retries
    end

    def failure_message
      "expected job to have callback retries #{@expected_retries} but has #{@actual_retries}"
    end

    def failure_message_when_negated
      "expected job not to have callback retries #{@expected_retries} but it does"
    end
  end

  def have_callback_retries(*args)
    HaveCallbackRetries.new(*args)
  end
end

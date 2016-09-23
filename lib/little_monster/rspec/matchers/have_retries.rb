module LittleMonster::RSpec::Matchers
  class HaveRetries
    def initialize(expected_retries)
      @expected_retries = expected_retries
    end

    def matches?(job)
      @job_class = if job.is_a? LittleMonster::Job
                     job.class
                   else
                     job.class == Class ? job : job.to_s.camelcase.constantize
                   end
      @actual_retries = @job_class.max_retries
      @actual_retries == @expected_retries
    end

    def failure_message
      "expected job to have retries #{@expected_retries} but has #{@actual_retries}"
    end

    def failure_message_when_negated
      "expected job not to have retries #{@expected_retries} but it does"
    end
  end

  def have_retries(*args)
    HaveRetries.new(*args)
  end
end

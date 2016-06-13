module LittleMonster::RSpec::Matchers
  class HaveRun
    def initialize(*expected_tasks)
      @expected_tasks = if expected_tasks.length == 1
                          expected_tasks.first
                        else
                          expected_tasks
                        end
    end

    def matches?(job_result)
      @actual_tasks = job_result.runned_tasks.keys
      @actual_tasks == @expected_tasks
    end

    def failure_message
      "expected job to run #{@expected_tasks} but instead run #{@actual_tasks}"
    end

    def failure_message_when_negated
      "expected job not to run #{@expected_tasks}"
    end
  end

  def have_run(*args)
    HaveRun.new(*args)
  end
end

module LittleMonster::RSpec::Matchers
  class Run
    def initialize(*expected_tasks)
      @expected_tasks = expected_tasks
    end

    def matches?(job)
      @job = job
      return false unless @job.class.tasks.length == @job.class.tasks.length
      @job.class.tasks.select { |v| @expected_tasks.include? v }.length == @job.class.tasks.length
    end

    def failure_message
      "expected job to have #{@expected_tasks} but had #{@job.class.tasks}"
    end

    def failure_message_when_negated
      "expected job not to have #{@expected_tasks}"
    end
  end

  def run(*args)
    Run.new(*args)
  end
end

module LittleMonster::RSpec::Matchers
  class HaveRunTask
    attr_reader :expected_task
    attr_reader :expected_params
    attr_reader :expected_previous_output
    attr_reader :expected_output

    def initialize(expected_task)
      @expected_task = if expected_task.class == Class
                         expected_task.to_s.underscore.split('/').last.to_sym
                       else
                         expected_task
                       end
    end

    def matches?(job)
      @task = job.runned_tasks[@expected_task][:instance]
      @task_output = job.runned_tasks[@expected_task][:output]
      check_task_run && check_params && check_output && check_previous_output
    end

    def check_task_run
      !@task.nil?
    end

    def check_params
      if defined?(@expected_params)
        @task.params == @expected_params
      else
        true
      end
    end

    def check_previous_output
      if defined?(@expected_previous_output)
        @task.previous_output == @expected_previous_output
      else
        true
      end
    end

    def check_output
      if defined?(@expected_output)
        @task_output == @expected_output
      else
        true
      end
    end

    def with_params(params)
      @expected_params = params
      self
    end

    def with_previous_output(previous_output)
      @expected_previous_output = previous_output
      self
    end

    def with_output(output)
      @expected_output = output
      self
    end

    def failure_message
      message = "task #{@expected_task} was expected to run\n"
      message << "\twith params #{@expected_params} but received #{@task.params || 'nil'}\n" unless check_params
      message << "\twith previous_output #{@expected_previous_output} but received #{@task.previous_output || 'nil'}\n" unless check_previous_output
      message << "\twith output #{@expected_output} but outputed #{@task.output || 'nil'}\n" unless check_output
      message
    end
  end

  def have_run_task(*args)
    HaveRunTask.new(*args)
  end
end

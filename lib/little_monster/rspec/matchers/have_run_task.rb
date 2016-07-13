module LittleMonster::RSpec::Matchers
  class HaveRunTask
    attr_reader :expected_task
    attr_reader :expected_params
    attr_reader :expected_previous_data
    attr_reader :expected_data

    def initialize(expected_task)
      @expected_task = if expected_task.class == Class
                         expected_task.to_s.underscore.split('/').last.to_sym
                       else
                         expected_task
                       end
    end

    def matches?(job)
      @task = job.runned_tasks[@expected_task][:instance]
      @task_data = job.runned_tasks[@expected_task][:data]
      check_task_run && check_params && check_data
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

    def check_data
      if defined?(@expected_data)
        @task_data == @expected_data
      else
        true
      end
    end

    def with_params(params)
      @expected_params = params
      self
    end

    def with_data(data)
      @expected_data = data
      self
    end

    def failure_message
      message = "task #{@expected_task} was expected to run\n"
      message << "\twith params #{@expected_params} but received #{@task.params || 'nil'}\n" unless check_params
      message << "\twith data #{@expected_data} but was #{@task_data || 'nil'}\n" unless check_data
      message
    end
  end

  def have_run_task(*args)
    HaveRunTask.new(*args)
  end
end

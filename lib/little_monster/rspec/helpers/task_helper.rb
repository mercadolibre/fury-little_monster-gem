module LittleMonster::RSpec
  module TaskHelper
    class Result
      attr_reader :output

      def initialize(task)
        @task = task
        @output = task.run
      end

      def instance
        @task
      end
    end

    def run_task(task, options = {})
      task = task.to_s.camelcase.constantize unless task.class == Class

      task_instance = task.new(options[:params], options[:output])
      task_instance.instance_variable_set('@cancelled_callback', (proc { true })) if options[:cancelled]

      Result.new(task_instance)
    end
  end
end

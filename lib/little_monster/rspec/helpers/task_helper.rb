module LittleMonster::RSpec
  module TaskHelper
    class Result
      def initialize(task)
        @task = task
        task.run
      end

      def instance
        @task
      end

      def data
        @task.data
      end
    end

    def run_task(task, options = {})
      task_instance = generate_task(task, options)
      task_instance.instance_variable_set('@cancelled_callback', (proc { true })) if options[:cancelled]

      Result.new(task_instance)
    end

    def generate_task(task, options = {}) # TODO: tests
      task_class = if task.class != Class
                      task.to_s.camelcase.constantize
                    else
                      task
                    end

      task_symbol = task.to_s.underscore.split('/').last.to_sym
      data = if options[:data].class == LittleMonster::Job::Data
                options[:data]
              else
                LittleMonster::Job::Data.new(double(current_task: task_symbol),
                                            outputs: options.fetch(:data, {}))
              end

      task_instance = task_class.new(options[:params], data)
      task_instance.send(:set_default_values, options[:params], data)
      return task_instance
    end
  end
end

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

      Result.new(task_instance)
    end

    def generate_task(task, options = {})
      task_class = if task.instance_of?(Class)
                     task
                   else
                     task.to_s.camelcase.constantize
                   end

      task_symbol = task.to_s.underscore.split('/').last.to_sym
      data = if options[:data].instance_of?(LittleMonster::Job::Data)
               options[:data]
             else
               LittleMonster::Job::Data.new(double(current_action: task_symbol),
                                            outputs: options.fetch(:data, {}))
             end

      task_instance = task_class.new(data)
      task_instance.send(:set_default_values,
                         data: data,
                         cancelled_callback: proc { options.fetch(:cancelled, false) },
                         cancelled_throw_callback: proc {
                                                     if options.fetch(:cancelled, false)
                                                       raise LittleMonster::CancelError
                                                     end
                                                   },
                         job_id: options.fetch(:job_id, nil),
                         retries: options.fetch(:job_retries, 0),
                         max_retries: options.fetch(:job_max_retries, 0),
                         retry_callback: proc { !options.fetch(:last_retry, false) })

      task_instance
    end
  end
end

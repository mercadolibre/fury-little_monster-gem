module LittleMonster::RSpec
  module TaskHelper
    def run_task(task, options = {})
      task = task.to_s.camelcase.constantize unless task.class == Class

      task_instance = task.new(options[:params], options[:previous_output])
      task_instance.instance_variable_set('@cancelled_callback', (proc { true })) if options[:cancelled]

      task_instance.perform
      task_instance
    end
  end
end

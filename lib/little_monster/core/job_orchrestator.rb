module LittleMonster::Core
  class Job::Orchrestator
    attr_reader :logger
    attr_reader :job

    def initialize(job)
      @job = job
      @logger = @job.logger
    end

    def run
      # notifies status as running and then restores old_status if it is an ending status
      last_status = @job.status
      @job.status = :running
      @job.notify_status

      if Job::ENDED_STATUS.include? last_status
        @job.status = last_status
      else
        run_tasks

        logger.default_tags.delete(:current_task)
        # reset retries so retries don't mix between tasks and callbacks
        @job.retries = 0
      end

      run_callback
      logger.info "[type:job_finish] [status:#{@job.status}] data: #{@job.data.to_h[:outputs]}"
    ensure
      options = {}
      options[:data] = @job.data if @job.ended_status?
      @job.notify_status options
    end

    def run_tasks
      @job.tasks_to_run.each do |task_name|
        @job.current_action = task_name
        @job.notify_task :running

        logger.default_tags[:current_task] = @job.current_action
        logger.info "[type:start_task] data: #{@job.data.to_h[:outputs]}"

        begin
          raise LittleMonster::CancelError if @job.is_cancelled?

          task = build_task(task_name)
          task.run

          # data is sent only on task success
          @job.notify_task :success, data: @job.data

          logger.info "[type:finish_task] [status:success] data: #{@job.data.to_h[:outputs]}"

          if @job.mock?
            @job.runned_tasks[task_name] = {}
            @job.runned_tasks[task_name][:instance] = task
            @job.runned_tasks[task_name][:data] = @job.data.to_h[:outputs].to_h.dup
          end
        rescue APIUnreachableError => e
          logger.error "[type:api_unreachable] [message:#{e.message}]"
          raise e
        rescue CancelError => e
          logger.info '[type:cancel] job was cancelled'
          cancel
          return
        rescue StandardError => e
          logger.debug "[type:standard_error] an error was catched with [message:#{e.message}]"
          task.error e unless e.is_a? NameError
          handle_error e
          return
        end

        @job.retries = 0 # Hago esto para que despues de succesful un task resete retries
      end

      @job.current_action = nil
      @job.status = :success
    end

    def run_callback
      @job.current_action = @job.callback_to_run

      return if @job.current_action.nil?

      logger.default_tags[:callback] = @job.current_action
      @job.notify_callback :running

      logger.info "[type:start_callback] data: #{@job.data.to_h[:outputs]}"
      begin
        logger.default_tags[:type] = 'callback_log'
        @job.public_send(@job.current_action)
      ensure
        logger.default_tags.delete(:type)
      end
      logger.info "[type:finish_callback] [status:success] data: #{@job.data.to_h[:outputs]}"

      @job.notify_callback :success

      @job.current_action = nil
      @job.retries = 0
      logger.default_tags.delete(:callback)
    rescue APIUnreachableError => e
      logger.error "[type:api_unreachable] [message:#{e.message}]"
      raise e
    rescue StandardError => e
      logger.debug "[type:standard_error] an error was catched with [message:#{e.message}]"
      handle_error e
    end

    def build_task(task_symbol)
      task = @job.task_class_for(task_symbol).new(@job.data)
      task.send(:set_default_values, @job.data, @job.id, logger, @job.method(:is_cancelled?))
      task
    end

    def cancel
      logger.debug 'notifiying cancel...'

      @job.notify_task :cancelled
      logger.info "[type:finish_task] [status:cancelled] data: #{@job.data.to_h[:outputs]}"

      @job.status = :cancelled
    end

    # Methods that work both on tasks and callbacks

    def abort_job(error)
      logger.debug 'notifiying abort...'

      if @job.callback_running?
        logger.info "[type:finish_callback] [status:error] data: #{@job.data.to_h[:outputs]}"
        @job.notify_callback :error, exception: error

        # if callback is not on_error, raise exception to run on_error
        if @job.current_action != :on_error
          # set status on pending because we are sending the job back to the queue
          @job.status = :pending
          raise CallbackFailedError, '[type:callback_fail_error]'
        end
      else
        @job.notify_task :error, exception: error
        logger.info "[type:finish_task] [status:error] data: #{@job.data.to_h[:outputs]}"
      end

      @job.status = :error
    end

    def handle_error(error)
      raise error if LittleMonster.env.development?
      logger.error "[type:error] [error_type:#{error.class}][message:#{error.message}] \n #{error.backtrace.to_a.join("\n\t")}"

      if error.is_a?(FatalTaskError) || error.is_a?(NameError)
        logger.debug 'error is fatal, aborting run'
        return abort_job(error)
      end

      do_retry(error)
    end

    def do_retry(error)
      if @job.retry?
        logger.debug "Retry ##{@job.retries} of #{@job.max_retries}"

        @job.retries += 1

        logger.debug 'notifiying retry'
        if @job.callback_running?
          @job.notify_callback :pending, retries: @job.retries, exception: error
          logger.info '[type:callback_retry]'
        else
          @job.notify_task :pending, retries: @job.retries, exception: error
          logger.info '[type:task_retry]'
        end

        @job.status = :pending

        logger.info "[type:job_retry] data: #{@job.data.to_h[:outputs]}"
        raise JobRetryError, "doing retry #{@job.retries} of #{@job.max_retries}"
      else
        logger.debug 'job has reached max retries'

        if @job.callback_running?
          logger.info '[type:callback_max_retries]'
        else
          logger.info '[type:task_max_retries]'
        end

        logger.info "[type:job_max_retries] [retries:#{@job.max_retries}]"
        abort_job(error)
      end
    end
  end
end

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

        # reset retries so retries don't mix between tasks and callbacks
        @job.retries = 0
      end

      run_callback
      logger.info "[type:job_finish] [status:#{@job.status}] [data:#{@job.data.to_h[:outputs]}]"
    ensure
      options = {}
      options[:data] = @job.data if @job.ended_status?
      @job.notify_status options
    end

    def run_tasks
      @job.tasks_to_run.each do |task_name|
        @job.current_task = task_name
        @job.notify_current_task :running

        logger.default_tags[:current_task] = @job.current_task
        logger.info "[type:start_task] [data:#{@job.data.to_h[:outputs]}]"

        begin
          raise LittleMonster::CancelError if @job.is_cancelled?

          task = build_task(task_name)
          task.run

          # data is sent only on task success
          @job.notify_current_task :success, data: @job.data

          logger.info "[type:finish_task] [status:success] [data:#{@job.data.to_h[:outputs]}]"

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

      logger.default_tags.delete(:current_task)
      @job.current_task = nil
      @job.status = :success
    end

    def run_callback
      @callback = @job.callback_to_run

      return if @callback.nil?

      logger.default_tags[:callback] = @callback
      @job.notify_callback @callback, :running

      begin
        logger.default_tags[:type] = 'callback_log'
        @job.public_send(@callback)
      ensure
        logger.default_tags.delete(:type)
      end

      @job.notify_callback @callback, :success

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

      @job.notify_current_task :cancelled
      @job.status = :cancelled
    end

    def callback_running?
      !@callback.nil?
    end

    # Methods that work both on tasks and callbacks

    def abort_job(_e)
      logger.debug 'notifiying abort...'

      if callback_running?
        @job.notify_callback @callback, :error
      else
        @job.notify_current_task :error
      end

      @job.status = :error
    end

    def handle_error(e)
      raise e if LittleMonster.env.development?
      logger.error "[type:error] [error_type:#{e.class}][message:#{e.message}] \n #{e.backtrace.to_a.join("\n\t")}"

      if e.is_a?(FatalTaskError) || e.is_a?(NameError)
        logger.debug 'error is fatal, aborting run'
        return abort_job(e)
      end

      do_retry
    end

    def do_retry
      if @job.retry?
        logger.debug "Retry ##{@job.retries} of #{@job.max_retries}"

        @job.retries += 1

        logger.debug 'notifiying retry'
        if callback_running?
          @job.notify_callback @callback, :pending, retries: @job.retries
          logger.info "[type:callback_retry] [data:#{@job.data.to_h[:outputs]}]"
        else
          @job.notify_current_task :pending, retries: @job.retries
          logger.info "[type:task_retry] [data:#{@job.data.to_h[:outputs]}]"
        end

        @job.status = :pending

        logger.info "[type:job_retry] [data:#{@job.data.to_h[:outputs]}]"
        raise JobRetryError, "doing retry #{@job.retries} of #{@job.max_retries}"
      else
        logger.debug 'job has reached max retries'

        logger.info "[type:job_max_retries] [retries:#{@job.max_retries}]"
        abort_job(MaxRetriesError.new)
      end
    end
  end
end

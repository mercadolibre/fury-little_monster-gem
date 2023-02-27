require 'newrelic_rpm'

module LittleMonster::Core
  class Job::Orchrestator
    extend ::NewRelic::Agent::MethodTracer

    attr_reader :logger, :job

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
      logger.info "[type:job_finish] [status:#{@job.status}] Job finished"
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
        logger.info "[type:start_task] Task #{task_name} started"

        begin
          @job.is_cancelled! critical: true

          task = build_task(task_name)
          self.class.trace_execution_scoped(["#{class_to_use(task_name)}#Run"]) do
            task.run
          end

          # data is sent only on task success
          @job.notify_task :success, data: @job.data

          logger.info '[type:finish_task] [status:success] Task finished!'

          if @job.mock?
            @job.runned_tasks[task_name] = {}
            @job.runned_tasks[task_name][:instance] = task
            @job.runned_tasks[task_name][:data] = @job.data.to_h[:outputs].to_h.dup
          end
        rescue APIUnreachableError => e
          logger.error "[type:api_unreachable] [message:#{e.message.dump}]"
          raise e
        rescue OwnershipLostError => e
          logger.error "[type:ownership_lost] [message:#{e.message.dump}]"
          raise e
        rescue CancelError => e
          logger.info '[type:cancel] job was cancelled'
          cancel
          return
        rescue StandardError => e
          logger.debug "[type:standard_error] an error was catched with [message:#{e.message.dump}]"
          begin
            task.error e unless e.is_a? NameError
          rescue StandardError => task_error
          ensure
            handle_error task_error || e
            return
          end
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

      logger.info '[type:start_callback] Started callback!'
      begin
        logger.default_tags[:type] = 'callback_log'
        @job.public_send(@job.current_action)
      ensure
        logger.default_tags.delete(:type)
      end
      logger.info '[type:finish_callback] [status:success] Finished callback!'

      @job.notify_callback :success

      @job.current_action = nil
      @job.retries = 0
      logger.default_tags.delete(:callback)
    rescue APIUnreachableError => e
      logger.error "[type:api_unreachable] [message:#{e.message.dump}]"
      raise e
    rescue StandardError => e
      logger.debug "[type:standard_error] an error was catched with [message:#{e.message.dump}]"
      handle_error e
    end

    def class_to_use(task_symbol)
      @job.task_class_for(task_symbol)
    end

    def build_task(task_symbol)
      task = class_to_use(task_symbol).new(@job.data)
      task.send(:set_default_values,
                data: @job.data,
                job_id: @job.id,
                job_logger: logger,
                cancelled_callback: @job.method(:is_cancelled?),
                cancelled_throw_callback: @job.method(:is_cancelled!),
                retries: @job.retries,
                max_retries: @job.max_retries,
                retry_callback: @job.method(:retry?))
      task
    end

    def cancel
      logger.debug 'notifiying cancel...'

      @job.notify_task :cancelled
      logger.info '[type:finish_task] [status:cancelled] Cancelled task!'

      @job.status = :cancelled
    end

    # Methods that work both on tasks and callbacks

    def abort_job(error)
      logger.debug 'notifiying abort...'

      if @job.callback_running?
        logger.info '[type:finish_callback] [status:error] Failed on callback'
        @job.notify_callback :error, exception: error

        # if callback is not on_error, raise exception to run on_error
        if @job.current_action != :on_error
          # set status on pending because we are sending the job back to the queue
          @job.status = :pending
          raise CallbackFailedError, '[type:callback_fail_error]'
        end
      else
        @job.notify_task :error, exception: error
        logger.info '[type:finish_task] [status:error] Failed on callback'
      end

      @job.status = :error
    end

    def handle_error(error)
      raise error if LittleMonster.env.development?

      if error.cause.nil?
        logger.error "[type:error] [error_type:#{error.class}][message:#{error.message.dump}] \n #{error.backtrace.to_a.join("\n\t")}"
      else
        logger.error "[type:error] [error_type:#{error.class}][message:#{error.message.dump}]" \
                     "\n\t#{error.backtrace.to_a.join("\n\t")}" \
                     "\nCaused by:" \
                     "\n\t#{error.cause.backtrace.to_a.join("\n\t")}"
      end

      @job.error = @job.serialize_error error

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

        logger.info '[type:job_retry] Job retry!'
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

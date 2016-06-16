module LittleMonster::Core
  class Job
    include Loggable

    class << self
      attr_reader :tasks

      def task_list(*tasks)
        @tasks = *tasks
      end

      def retries(value)
        @max_retries = value
      end

      def task_class_for(task_name)
        "#{to_s.underscore}/#{task_name}".camelcase.constantize
      end

      def max_retries
        @max_retries ||= -1
      end

      def mock!
        @@mock = true
      end

      def mock?
        @@mock ||= false
      end

      def send_api_heartbeat(job_id)
        API.put "/job/#{job_id}/worker", body: { pid: Process.pid }
      end
    end

    attr_reader :current_task
    attr_reader :params
    attr_reader :output
    attr_reader :status

    def initialize(params)
      logger.debug "Starting with #{params}"
      @retries = 0 # TODO: traer esto de la api
      @params = params.freeze
      @current_task = nil
      @status = :pending

      @runned_tasks = {} if mock?
    end

    def run
      notify_status :running
      @output = {}

      self.class.tasks.each do |task_name|
        logger.debug "Starting #{task_name} with output => #{@output}"

        notify_current_task task_name, :running

        begin
          raise LittleMonster::CancelError if is_cancelled?

          task = task_class_for(task_name).new(@params, @output)
          task.send(:set_default_values, @params, @output, method(:is_cancelled?))

          @output = task.run
          notify_current_task task_name, :finished

          logger.debug "Succesfuly finished #{task_name}"

          if mock?
            @runned_tasks[task_name] = {}
            @runned_tasks[task_name][:instance] = task
            @runned_tasks[task_name][:output] = @output
          end
        rescue CancelError => e
          cancel e
          return
        rescue StandardError => e
          task.error e unless e.is_a? NameError
          error e
          return
        end

        # @retries = 0 #Hago esto para que despues de succesful un task resete retries
      end

      notify_current_task nil
      notify_status :finished

      logger.info "[job:#{self.class}] [action:finish] #{@output}"
      logger.info 'Succesfuly finished'
      # TODO: report to the api job finished
      @output
    end

    def on_error(error)
    end

    def on_abort(error)
    end

    def on_cancel
    end

    def mock?
      self.class.mock?
    end

    private

    attr_writer :status

    def is_cancelled?
      # TODO: checks against the api if job cancelled
      false # by default is false
    end

    def do_retry
      if self.class.max_retries == -1 || self.class.max_retries > @retries
        @retries += 1
        logger.info "Retry ##{@retries} of #{self.class.max_retries}"

        notify_status :pending
        notify_current_task current_task, :pending

        raise JobRetryError, "doing retry #{@retries} of #{self.class.max_retries}"
      else
        logger.error 'Max retries'
        # TODO: ponerle infomacion al error
        abort_job(MaxRetriesError.new)
      end
    end

    def abort_job(e)
      logger.info "Failed with #{e.class} Error description => #{e.message}"

      notify_status :error
      notify_current_task current_task, :error

      on_abort e
    end

    def cancel(e)
      logger.info "cancelled. Description => #{e.message}"

      notify_status :cancelled
      notify_current_task current_task, :cancelled

      on_cancel
    end

    def error(e)
      return abort_job(e) if e.is_a?(FatalTaskError) || e.is_a?(NameError)

      logger.error e.message

      on_error e
      do_retry
    end

    def notify_status(next_status)
      @status = next_status
      # TODO: notify api
    end

    def notify_current_task(task, status=:running)
      @current_task = task
      # TODO: notify api
    end

    def task_class_for(task_name)
      self.class.task_class_for task_name
    end
  end
end

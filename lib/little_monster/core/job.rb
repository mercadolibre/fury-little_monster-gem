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
    end

    attr_reader :id
    attr_reader :params
    attr_reader :tags
    attr_reader :status

    attr_reader :retries
    attr_reader :current_task
    attr_reader :output

    def initialize(options = {})
      @id = options.fetch(:id, nil)
      @params = options.fetch(:params, {}).freeze
      @tags = options.fetch(:tags, {}).freeze

      @retries = options.fetch(:retries, 0)
      @current_task = options.fetch(:current_task, nil)
      @output = options.fetch(:last_output, nil)

      @status = :pending

      @runned_tasks = {} if mock?
      # TODO: setup logger
      logger.debug "Starting with #{params}"
    end

    def run
      notify_status :running

      self.class.tasks.each do |task_name|
        logger.debug "Starting #{task_name} with output => #{@output}"

        notify_current_task task_name, :running

        begin
          raise LittleMonster::CancelError if is_cancelled?

          task = task_class_for(task_name).new(@params, @output)
          task.send(:set_default_values, @params, @output, method(:is_cancelled?))

          @output = task.run
          notify_current_task task_name, :finished, output: @output

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

        @retries = 0 # Hago esto para que despues de succesful un task resete retries
      end

      notify_status :finished, output: @output

      logger.info "[job:#{self.class}] [action:finish] #{@output}"
      logger.info 'Succesfuly finished'
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

    def do_retry
      if self.class.max_retries == -1 || self.class.max_retries > @retries
        @retries += 1
        logger.info "Retry ##{retries} of #{self.class.max_retries}"

        notify_status :pending
        notify_current_task current_task, :pending, retry: retries

        raise JobRetryError, "doing retry #{retries} of #{self.class.max_retries}"
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

    def notify_status(next_status, _options = {})
      @status = next_status
      # TODO: notify api
    end

    def notify_current_task(task, _status = :running, _options = {})
      @current_task = task
      # TODO: notify api status and options
    end

    def is_cancelled?
      # TODO: checks against the api if job cancelled
      false # by default is false
    end

    def task_class_for(task_name)
      self.class.task_class_for task_name
    end
  end
end

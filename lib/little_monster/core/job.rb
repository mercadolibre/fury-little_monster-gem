module LittleMonster::Core
  class Job
    include Loggable

    class << self
      attr_reader :tasks

      def task_list(*tasks)
        @tasks = *tasks
      end

      def max_retries(value)
        @max_ret = value
      end

      def task_class_for(task_name)
        "#{to_s.underscore}/#{task_name}".camelcase.constantize
      end

      def max_ret
        @max_ret ||= -1
      end

      def mock!
        @@mock = true
      end

      def mock?
        @@mock ||= false
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
      # TODO: report to the api job started
      self.status = :running
      @output = {}

      self.class.tasks.each do |task_name|
        logger.debug "Starting #{task_name} with output => #{@output}"
        @current_task = task_name

        # TODO: report to the api task started
        begin
          raise LittleMonster::CancelError if is_cancelled?

          task = task_class_for(task_name).new(@params, @output)
          task.send(:set_default_values, @params, @output, method(:is_cancelled?))
          @output = task.perform

          # TODO: report to api task succesful
          logger.debug "Succesfuly finished #{task_name}"

          @runned_tasks[task_name] = task if mock?
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

      @current_task = nil
      self.status = :finished
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
      if self.class.max_ret == -1 || self.class.max_ret > @retries
        @retries += 1
        logger.info "Retry ##{@retries} of #{self.class.max_ret}"
        # TODO: guarda el estado y lo manda a la api
        # TODO put message in queue
      else
        logger.error 'Max retries'
        # TODO: ponerle infomacion al error
        abort_job(LittleMonster::MaxRetriesError.new)
      end
    end

    def abort_job(e)
      # TODO: report to the api task->failed
      logger.info "Failed. Error description => #{e.message}"
      self.status = :failed
      on_abort e
      # TODO: calls rollback
    end

    def cancel(e)
      self.status = :cancelled
      # TODO: report to the api job efectivly cancelled
      logger.info "cancelled. Description => #{e.message}"
      on_cancel
    end

    def error(e)
      self.status = :error
      return abort_job(e) if e.is_a? FatalTaskError
      logger.error e.message
      # TODO: report to the api task->error
      on_error e
      # TODO: put message in queue
      do_retry
    end

    def task_class_for(task_name)
      self.class.task_class_for task_name
    end
  end
end

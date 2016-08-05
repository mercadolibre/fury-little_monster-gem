module LittleMonster::Core
  class Job
    include Loggable

    ENDED_STATUS = %w(success error cancelled).freeze

    class << self
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

      def tasks
        @tasks ||= []
      end

      def mock?
        @@mock ||= false
      end
    end

    attr_accessor :id
    attr_accessor :tags
    attr_accessor :status

    attr_accessor :retries
    attr_accessor :current_task
    attr_accessor :data

    attr_reader :orchrestator

    def initialize(options = {})
      @id = options.fetch(:id, nil)
      @tags = (options[:tags] || {}).freeze

      @retries = options[:retries] || 0
      @current_task = options.fetch(:current_task, self.class.tasks.first)

      @data = if options[:data]
                Data.new(self, options[:data])
              else
                Data.new(self)
              end

      @status = options.fetch(:status, :pending)

      @orchrestator = Job::Orchrestator.new(self)

      @runned_tasks = {} if mock?

      logger.default_tags = tags.merge(
        id: @id,
        job: self.class.to_s,
        retry: @retries
      )

      logger.info "[type:start_job] Starting job with [data:#{data.to_h[:outputs]}]"
    end

    def run
      @orchrestator.run
    end

    def mock?
      self.class.mock?
    end

    def do_retry
      if self.class.max_retries == -1 || self.class.max_retries > @retries
        logger.debug "Retry ##{retries} of #{self.class.max_retries}"

        @retries += 1

        logger.debug 'notifiying retry'

        notify_status :pending
        notify_current_task current_task, :pending, retries: retries

        logger.info "[type:job_retry] [data:#{@data.to_h[:outputs]}]"
        raise JobRetryError, "doing retry #{retries} of #{self.class.max_retries}"
      else
        logger.debug 'job has reached max retries'

        logger.info "[type:job_max_retries] [retries:#{self.class.max_retries}]"
        abort_job(MaxRetriesError.new)
      end
    end

    def abort_job(e)
      logger.debug 'notifiying abort...'

      notify_status :error
      notify_current_task current_task, :error

      on_error e

      logger.info "[type:job_finish] [status:error] [data:#{@data.to_h[:outputs]}]"
    end

    def cancel(_e)
      logger.debug 'notifiying cancel...'

      notify_status :cancelled
      notify_current_task current_task, :cancelled

      on_cancel

      logger.info "[type:job_finish] [status:cancelled] [data:#{@data.to_h[:outputs]}]"
    end

    def error(e)
      raise e if LittleMonster.env.development?
      logger.error "[type:error] [error_type:#{e.class}][message:#{e.message}] \n #{e.backtrace.to_a.join("\n\t")}"

      if e.is_a?(FatalTaskError) || e.is_a?(NameError)
        logger.debug 'error is fatal, aborting run'
        return abort_job(e)
      end

      do_retry
    end

    def notify_status(next_status = self.status, options = {})
      @status = next_status

      params = { body: { status: @status } }
      params[:body].merge!(options)

      notify_job params, retries: LittleMonster.job_requests_retries,
                         retry_wait: LittleMonster.job_requests_retry_wait
    end

    def notify_current_task(task, status = :running, options = {})
      @current_task = task

      params = { body: { tasks: [{ name: task, status: status }] } }
      params[:body][:data] = options[:data] if options[:data]

      params[:body][:tasks].first.merge!(options.except(:data))

      notify_job params, retries: LittleMonster.task_requests_retries,
                         retry_wait: LittleMonster.task_requests_retry_wait
    end

    def notify_callback(callback, status, options = {})
      return true unless should_request?
      params = { body: { name: callback, status: status } }
      params[:body].merge!(options)

      resp = LittleMonster::API.put "/jobs/#{id}/job_callbacks/#{callback}", params, options,
        retries: LittleMonster.task_requests_retries,
        retry_wait: LittleMonster.task_requests_retry_wait
      resp.success?
    end

    def notify_job(params={}, options={})
      return true unless should_request?
      options[:critical] = true

      params[:body][:data] = params[:body][:data].to_h

      resp = LittleMonster::API.put "/jobs/#{id}", params, options
      resp.success?
    end

    def is_cancelled?
      return false unless should_request?
      resp = LittleMonster::API.get "/jobs/#{id}"

      if resp.success?
        resp.body[:cancel]
      else
        false
      end
    end

    def should_request?
      !(mock? || LittleMonster.disable_requests?)
    end

    def task_class_for(task_name)
      self.class.task_class_for task_name
    end

    def retry?
      self.class.max_retries == -1 || self.class.max_retries > @retries
    end

    def max_retries
      self.class.max_retries
    end

    def callback_to_run
      case @status
      when :success
        :on_success
      when :error
        :on_error
      when :cancelled
        :on_cancel
      end
    end

    #returns the tasks that will be runned for this instance
    def tasks_to_run
      task_index = self.class.tasks.find_index(@current_task)

      return [] if task_index.nil?
      self.class.tasks.slice(task_index..-1)
    end

    def on_error
    end

    def on_cancel
    end

    def on_success
    end
  end
end

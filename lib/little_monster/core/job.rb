require 'newrelic_rpm'

module LittleMonster::Core
  class Job
    include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
    include Loggable

    ENDED_STATUS = %i(success error cancelled).freeze
    CALLBACKS = %i(on_success on_error on_cancel).freeze

    class << self
      def task_list(*tasks)
        @tasks = *tasks
      end

      def retries(value)
        @max_retries = value
      end

      def callback_retries(value)
        @callback_max_retries = value
      end

      def task_class_for(task_name)
        "#{to_s.underscore}/#{task_name}".camelcase.constantize
      rescue NameError
        task_name.to_s.camelcase.constantize
      end

      def max_retries
        @max_retries ||= LittleMonster.default_job_retries
      end

      def callback_max_retries
        @callback_max_retries ||= max_retries
      end

      def mock!
        @mock = true
      end

      def tasks
        @tasks ||= []
      end

      def mock?
        @mock ||= false
      end
    end

    attr_accessor :id
    attr_accessor :tags
    attr_accessor :status

    attr_accessor :retries
    attr_accessor :current_action
    attr_accessor :data
    attr_accessor :error

    attr_reader :orchrestator

    def initialize(options = {})
      @id = options.fetch(:id, nil)
      @tags = (options[:tags] || {}).freeze
      @worker_id = options.fetch(:worker_id, nil)

      @retries = options[:retries] || 0

      @current_action = options.fetch(:current_action, self.class.tasks.first)

      @data = if options[:data]
                Data.new(self, options[:data])
              else
                Data.new(self)
              end

      @status = options.fetch(:status, :pending)
      @error= options.fetch(:error, {})

      @orchrestator = Job::Orchrestator.new(self)

      if mock?
        @runned_tasks = {}
        self.class.send :attr_reader, :runned_tasks
      end

      logger.default_tags = tags.merge(
        id: @id,
        job: self.class.to_s,
        retry: @retries
      )

      logger.info "[type:start_job] Starting job"
    end

    def run
      @orchrestator.run
    end

    def notify_status(options = {})
      params = { body: { status: @status } }
      params[:body].merge!(options)

      notify_job params, retries: LittleMonster.job_requests_retries,
                         retry_wait: LittleMonster.job_requests_retry_wait
    end

    def notify_task(status, options = {})
      params = { body: { tasks: [{ name: @current_action, status: status }] } }

      params[:body][:data] = options[:data] if options[:data]
      params[:body][:tasks].first[:exception] = serialize_error(options[:exception]) if options[:exception]

      params[:body][:tasks].first.merge!(options.except(:data, :exception))

      notify_job params, retries: LittleMonster.task_requests_retries,
                         retry_wait: LittleMonster.task_requests_retry_wait
    end

    def notify_callback(status, options = {})
      return true unless should_request?
      params = { body: { name: @current_action, status: status } }

      params[:body][:exception] = serialize_error(options[:exception]) if options[:exception]

      params[:body].merge!(options.except(:exception))

      resp = LittleMonster::API.put "/jobs/#{id}/callbacks/#{@current_action}", params,
                                    retries: LittleMonster.task_requests_retries,
                                    retry_wait: LittleMonster.task_requests_retry_wait
      resp.success?
    end

    def notify_job(params = {}, options = {})
      return true unless should_request?
      options[:critical] = true

      params[:body][:data] = params[:body][:data].to_h if params[:body][:data]

      resp = LittleMonster::API.put "/jobs/#{id}", params, options
      resp.success?
    end

    def check_abort_cause
      return nil unless should_request?
      resp = LittleMonster::API.get "/jobs/#{id}"

      if resp.success?
        return :cancel if resp.body[:cancel]
        return :ownership_lost unless is_current_worker?(resp.body[:worker])
      end
      nil
    end

    def is_cancelled?
      !check_abort_cause.nil?
    end

    def is_cancelled!
      case check_abort_cause
      when :cancel
        raise CancelError
      when :ownership_lost
        raise OwnershipLostError
      end
    end

    def is_current_worker?(current_worker)
      @worker_id.nil? || @worker_id == LittleMonster::Core::WorkerId.new(current_worker)
    end

    def task_class_for(task_name)
      self.class.task_class_for task_name
    end

    def max_retries
      callback_running? ? self.class.callback_max_retries : self.class.max_retries
    end

    def retry?
      !mock? && (max_retries == -1 || max_retries > @retries)
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

    # returns the tasks that will be runned for this instance
    def tasks_to_run
      return [] if callback_running?
      task_index = self.class.tasks.find_index(@current_action)

      return [] if task_index.nil?
      self.class.tasks.slice(task_index..-1)
    end

    def callback_running?
      return false if @current_action.nil? || self.class.tasks.include?(@current_action)
      CALLBACKS.include? @current_action
    end

    def ended_status?
      Job::ENDED_STATUS.include? @status
    end

    def mock?
      self.class.mock?
    end

    def should_request?
      !(mock? || LittleMonster.disable_requests?)
    end

    def serialize_error(error)
      # encode error message to UTF-8 and remove invalid characters or MultiJson breaks
      {
        message: error.message.encode('UTF-8', invalid: :replace, replace: ''),
        type: error.class.to_s,
        retry: @retries
      }
    end

    # callbacks definition
    def on_error ; end
    def on_success ; end
    def on_cancel ; end

    add_transaction_tracer :run
  end
end

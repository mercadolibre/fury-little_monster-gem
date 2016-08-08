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

      if mock?
        @runned_tasks = {}
        self.class.send :attr_reader, :runned_tasks
      end

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

    def notify_status(options = {})
      params = { body: { status: @status } }
      params[:body].merge!(options)

      notify_job params, retries: LittleMonster.job_requests_retries,
                         retry_wait: LittleMonster.job_requests_retry_wait
    end

    def notify_current_task(status, options = {})
      params = { body: { tasks: [{ name: @current_task, status: status }] } }
      params[:body][:data] = options[:data] if options[:data]

      params[:body][:tasks].first.merge!(options.except(:data))

      notify_job params, retries: LittleMonster.task_requests_retries,
                         retry_wait: LittleMonster.task_requests_retry_wait
    end

    def notify_callback(callback, status, options = {})
      return true unless should_request?
      params = { body: { name: callback, status: status } }
      params[:body].merge!(options)

      resp = LittleMonster::API.put "/jobs/#{id}/job_callbacks/#{callback}", params,
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

    def max_retries
      self.class.max_retries
    end

    def retry?
      max_retries == -1 || max_retries > @retries
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

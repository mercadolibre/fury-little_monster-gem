module LittleMonster::Core
  class Job::Factory
    include Loggable

    def initialize(worker_id, message = {})
      @worker_id = worker_id
      @id = message[:id]
      @name = message[:name]

      # it converts tags from array of hashes to a single hash
      @tags = Hash[message.fetch(:tags, []).map { |h| [h.keys.first, h.values.first] }].freeze

      logger.default_tags = @tags.merge(id: @id, name: @name)

      @api_attributes = fetch_attributes.freeze

      # this gets saved for development run and debugging purposes
      @input_data = message[:data]

      begin
        @job_class = @name.to_s.camelcase.constantize
      rescue NameError
        raise JobClassNotFoundError.new(@id), "[type:error] job [name:#{@name}] does not exists"
      end
    end

    def build
      if discard?
        logger.info "[type:discard] discarding job with [status:#{(@api_attributes || {}).fetch(:status, 'nil')}]"
        return
      end

      unless LittleMonster.disable_requests?
        notify_job_task_list
        notify_job_max_retries
      end

      @job_class.new job_attributes
    end

    def notify_job_task_list
      return true unless @api_attributes[:tasks].blank?

      params = {
        body: {
          tasks: @job_class.tasks.each_with_index.map { |task, index| { name: task, order: index } }
        }
      }

      res = LittleMonster::API.post "/jobs/#{@id}/tasks", params, retries: LittleMonster.job_requests_retries,
                                                                  retry_wait: LittleMonster.job_requests_retry_wait,
                                                                  critical: true

      return true if res.success? || res.code == 400 # don't fail if request has succeded or if status is 400 (tasks have already been created)

      raise JobNotFoundError, "[type:error] job [id:#{@id}] does not exists" if res.code == 404
      raise APIUnreachableError, "[type:error] failed to notify task list [status:#{res.code}]"
    end

    def notify_job_max_retries
      return true unless @api_attributes[:max_retries].blank?

      params = {
        body: {
          max_retries: @job_class.max_retries,
          callback_retries: @job_class.callback_max_retries
        }
      }

      res = LittleMonster::API.put "/jobs/#{@id}", params, retries: LittleMonster.job_requests_retries,
                                                           retry_wait: LittleMonster.job_requests_retry_wait
      res.success?
    end

    def fetch_attributes
      return {} if LittleMonster.disable_requests?
      resp = API.get "/jobs/#{@id}", {}, retries: LittleMonster.job_requests_retries,
                                         retry_wait: LittleMonster.job_requests_retry_wait,
                                         critical: true

      raise JobNotFoundError, "[type:error] job [id:#{@id}] does not exists" if resp.code == 404

      if !resp.success?
        logger.error("Failed to get api attributes unsuccessful response: #{resp.inspect} success: #{resp.success?}")
        raise APIUnreachableError, "failed to fetch attributes [status:#{resp.code}]"
      end

      if resp.body.nil? || resp.body[:status].nil?
        logger.error("Failed to get api attributes body: #{resp.body.inspect}")
        raise StandardError, "empty api attributes"
      end

      return resp.body
    end

    def calculate_status_and_error
      return [:pending, {}] if @api_attributes[:tasks].blank?

      # FIRST we check if any callback has failed to set error status
      @api_attributes.fetch(:callbacks, []).each do |callback|
        return [:error, callback[:exception] || {}] if callback[:status].to_sym == :error
      end

      # if no callback has fail we get the status from the tasks
      @api_attributes[:tasks].sort_by! { |task| task[:order] }.each do |task|
        return [task[:status].to_sym, task[:exception] || {}] if task[:status].to_sym != :success
      end

      [:success, {}]
    end

    def find_current_action_and_retries
      return [@job_class.tasks.first, 0] if @api_attributes[:tasks].blank?

      # callbacks and tasks both have name, retries and status
      # that means we can search through them with the same block

      search_array = if @api_attributes.fetch(:callbacks, []).blank?
                       # callbacks have not run yet, so we look for tasks
                       @api_attributes[:tasks].sort_by { |task| task[:order] }
                     else
                       @api_attributes[:callbacks]
                     end

      current = search_array.find do |x|
        !Job::ENDED_STATUS.include? x[:status].to_sym
      end
      return nil unless current

      [current[:name].to_sym, current[:retries]]
    end

    def job_attributes
      data = if !@api_attributes[:data].nil?
               @api_attributes[:data]
             else
               @input_data
             end

      attributes = {
        id: @id,
        data: data,
        tags: @tags,
        worker_id: @worker_id
      }

      return attributes if LittleMonster.disable_requests?

      # these two attribute retrival methods are arranged in this way
      # because each one filters the tasks based on different statuses
      status, error = calculate_status_and_error
      current_action, retries = find_current_action_and_retries

      attributes.merge(status: status,
                       current_action: current_action,
                       error: error,
                       retries: retries)
    end

    def discard?
      @api_attributes.nil? || Job::ENDED_STATUS.include?(@api_attributes.fetch(:status, :pending).to_sym)
    end
  end
end

module LittleMonster::Core
  class Job::Factory
    include Loggable

    def initialize(message = {})
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
        raise JobNotFoundError.new(@id), "[type:error] job [name:#{@name}] does not exists"
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
      res.success?
    end

    def notify_job_max_retries
      return true unless @api_attributes[:max_retries].blank?

      params = {
        body: { max_retries: @job_class.max_retries }
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

      resp.success? ? resp.body : nil
    end

    def calculate_status
      return :pending if @api_attributes[:tasks].blank?

      #FIRST we check if any callback has fail so set error status if necessary
      @api_attributes.fetch(:callbacks, []).each do |callback|
        return :error if callback[:status].to_sym == :error
      end

      #if no callback has fail we get the status from the tasks
      @api_attributes[:tasks].sort_by! { |task| task[:order] }.each do |task|
        return task[:status].to_sym if task[:status].to_sym != :success
      end

      :success
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
        tags: @tags
      }

      return attributes if LittleMonster.disable_requests?

      status = calculate_status
      current_action, retries = find_current_action_and_retries

      attributes.merge(status: status,
                       current_action: current_action,
                       retries: retries)
    end

    def discard?
      @api_attributes.nil? || Job::ENDED_STATUS.include?(@api_attributes.fetch(:status, :pending).to_sym)
    end
  end
end

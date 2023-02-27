module LittleMonster::Core
  class Runner
    include Loggable

    def initialize(params)
      @params = params
      @worker_id = LittleMonster::Core::WorkerId.new

      @heartbeat_task = Concurrent::TimerTask.new(execution_interval: LittleMonster.heartbeat_execution_interval) do |task|
        send_heartbeat!
      rescue LittleMonster::JobAlreadyLockedError => e
        # prevent excessive heartbeating and accidental lock owning if we don't own the lock
        task.shutdown
        raise e
      rescue LittleMonster::JobNotFoundError => e
        # prevent excessive heartbeating when job does not exist
        task.shutdown
        raise e
      rescue LittleMonster::APIUnreachableError => e
        logger.error "[id:#{@params[:id]}][type:lm_api_fail] [message:#{e.message.dump}] \n #{e.backtrace.to_a.join("\n\t")}"
        raise e
      end
    end

    def run
      send_heartbeat!

      @heartbeat_task.execute unless LittleMonster.disable_requests?

      job = LittleMonster::Job::Factory.new(@worker_id, @params).build
      job&.run
    rescue JobNotFoundError => e
      logger.error "[id:#{@params[:id]}][type:job_not_found] [message:#{e.message.dump}] \n #{e.backtrace.to_a.join("\n\t")}"
    rescue JobClassNotFoundError => e
      logger.error "[id:#{@params[:id]}][type:job_class_not_found] [message:#{e.message.dump}] \n #{e.backtrace.to_a.join("\n\t")}"
    ensure
      @heartbeat_task.shutdown
    end

    def send_heartbeat!
      return if LittleMonster.disable_requests?

      params = {
        body: @worker_id.to_h,
        timeout: 9 # heartbeat interval is 10s, timeout at 9s
      }
      res = LittleMonster::API.put "/jobs/#{@params[:id]}/worker", params, critical: true

      if res.code == 401
        raise LittleMonster::JobAlreadyLockedError,
              "job [id:#{@params[:id]}] is already locked, discarding"
      end
      raise LittleMonster::JobNotFoundError, "[type:error] job [id:#{@params[:id]}] does not exists" if res.code == 404

      unless res.success?
        raise LittleMonster::APIUnreachableError,
              "job [id:#{@params[:id]}] unsuccessful lock [status:#{res.code}]"
      end

      true
    end
  end
end

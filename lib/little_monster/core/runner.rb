module LittleMonster::Core
  class Runner
    include Loggable

    def initialize(params)
      @params = params

      @thread_id = Thread.current.object_id
      @heartbeat_task = Concurrent::TimerTask.new(execution_interval: LittleMonster.heartbeat_execution_interval) do
        send_heartbeat!
      end
    end

    def run
      send_heartbeat!

      @heartbeat_task.execute unless LittleMonster.disable_requests?

      job = LittleMonster::Job::Factory.new(@params).build
      job.run unless job.nil?
    rescue JobNotFoundError => e
      logger.error "[id:#{@params[:id]}][type:job_not_found] [message:#{e.message.dump}] \n #{e.backtrace.to_a.join("\n\t")}"
    ensure
      @heartbeat_task.shutdown
    end

    def send_heartbeat!
      return if LittleMonster.disable_requests?

      params = {
        body: {
          ip: Socket.gethostname,
          host: Socket.gethostname,
          pid: "#{Process.pid}-#{@thread_id}"
        }
      }
      res = LittleMonster::API.put "/jobs/#{@params[:id]}/worker", params, critical: true

      raise LittleMonster::JobAlreadyLockedError, "job [id:#{@params[:id]}] is already locked, discarding" if res.code == 401
      res.success?
    end
  end
end

module LittleMonster::Core
  class Runner
    include Loggable

    def initialize(params)
      @params = params

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
      logger.error "[type:job_not_found] [message:#{e.message}] \n #{e.backtrace.to_a.join("\n\t")}"
    ensure
      @heartbeat_task.shutdown
    end

    def send_heartbeat!
      return if LittleMonster.disable_requests?

      res = LittleMonster::API.put "/jobs/#{@params[:id]}/worker", body: {
        ip: Socket.gethostname,
        host: Socket.gethostname,
        pid: Process.pid
      }

      raise LittleMonster::JobAlreadyLockedError, "job [id:#{@params[:id]}] is already locked, discarding" if res.code == 401
      res.success?
    end
  end
end

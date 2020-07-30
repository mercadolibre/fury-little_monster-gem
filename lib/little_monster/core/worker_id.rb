module LittleMonster::Core
  class WorkerId
    attr_reader :host, :pid

    def initialize(host: nil, pid: nil)
      @host = host.nil? ? Socket.gethostname.freeze : host.freeze
      @pid = pid.nil? ? "#{Process.pid}-#{Thread.current.object_id}".freeze : pid.freeze
    end

    def has_lock?(lock)
      host == lock[:host] &&
        pid == lock[:pid]
    end

    def to_h
      {
        host: @host,
        pid: @pid
      }
    end
  end
end

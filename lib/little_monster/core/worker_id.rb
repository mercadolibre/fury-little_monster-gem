module LittleMonster::Core
  class WorkerId
    attr_reader :ip, :host, :pid

    def initialize(ip: nil, host: nil, pid: nil)
      @ip = ip.nil? ? Socket.gethostname.freeze : ip.freeze
      @host = host.nil? ? Socket.gethostname.freeze : host.freeze
      @pid = pid.nil? ? "#{Process.pid}-#{Thread.current.object_id}".freeze : pid.freeze
    end

    def ==(other)
      self.ip  == other.ip &&
        self.host == other.host &&
        self.pid == other.pid
    end

    def to_h
      {
        ip: @ip,
        host: @host,
        pid: @pid
      }
    end
  end
end

module LittleMonster::Core
  class Runner
    attr_reader :job_class
    attr_reader :params

    def initialize(job_name, params=nil)
      @job_class = if job_name.class == Class
                     job_name
                   else
                     job_name.to_s.camelcase.constantize
                   end
      @params = params

    rescue NameError
      raise JobNotFoundError, "no job found for #{job_name}"
    end

    def run
      @job_class.new(@params).run
    end
  end
end

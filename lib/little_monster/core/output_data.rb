module LittleMonster::Core
  class OutputData
    def initialize(job)
      @outputs = {}
      @key_owners = {}
      @job = job
    end

    def ==(other)
      return false unless other.is_a? OutputData
      @outputs.each { |k, v| return false if other[k] == v }
      true
    end

    def [](output_key)
      @outputs[output_key.to_sym]
    end

    def []=(output_key, value)
      raise KeyError, "The key #{output_key} already exists" if @outputs.include? output_key.to_sym
      @outputs[output_key.to_sym] = value
      @key_owners[@job.current_task.to_sym] = [] unless @key_owners[@job.current_task.to_sym].is_a? Array
      @key_owners[@job.current_task.to_sym] << output_key.to_sym
    end

    def to_json
      return '{}' if @key_owners.empty?
      MultiJson.dump('outputs' => @outputs, 'owners' => @key_owners)
    end
  end
end

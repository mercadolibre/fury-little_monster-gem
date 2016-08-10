module LittleMonster::Core
  class Job::Data
    def initialize(job, input = {})
      @outputs = input.fetch(:outputs, {})
      @key_owners = input.fetch(:owners, {})
      @job = job
    end

    def ==(other)
      return false unless is_valid?(other) && other.length == length
      @outputs.each { |k, v| return false unless other[k.to_sym] == v }
      true
    end

    def [](output_key)
      @outputs[output_key.to_sym]
    end

    def []=(output_key, value)
      raise KeyError, "The key #{output_key} already exists" if @outputs.include? output_key.to_sym
      @outputs[output_key.to_sym] = value

      owner = (@job.current_task || @job.current_action).to_sym
      @key_owners[owner] = [] unless @key_owners[owner].is_a? Array
      @key_owners[owner] << output_key.to_sym
    end

    def to_json
      MultiJson.dump(to_h)
    end

    def to_h
      return {} if @outputs.empty?
      { outputs: @outputs, owners: @key_owners }
    end

    def length
      @outputs.length
    end

    private

    def is_valid?(other)
      other.instance_of?(Job::Data) || other.instance_of?(Hash)
    end
  end
end

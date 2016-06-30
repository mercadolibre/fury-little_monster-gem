module LittleMonster::Core
  class OutputData
    def initialize
      @outputs = {}
      @key_owners = {}
    end

    def give_to(task)
      @current_task = task.to_sym
      @key_owners[@current_task] = []
      self
    end

    def [](output_key)
      @outputs[output_key.to_sym]
    end

    def []=(output_key, value)
      raise KeyError, "The key #{output_key} already exists" if @outputs.include? output_key.to_sym
      @outputs[output_key.to_sym] = value
      @key_owners[@current_task] << output_key.to_sym
    end

    def to_json
      return '{}' if @key_owners.empty?
      MultiJson.dump('outputs' => @outputs, 'owners' => @key_owners)
    end
  end
end

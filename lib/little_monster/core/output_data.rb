module LittleMonster::Core
  class OutputData
    def initialize
      @outputs = {}
      @key_owners = {}
    end

    def give_to(task)
      @current_task = task
      @key_owners[@current_task] = []
      return self
    end

    def [] (output_key)
      return @outputs[output_key.to_sym]
    end

    def []= (output_key, value)
      raise KeyError, "The key #{output_key} already exists" if @outputs.include? output_key.to_sym
      @outputs[output_key.to_sym] = value
      @key_owners[@current_task] << output_key.to_sym
    end

    def to_s
      res = ''
      @outputs.each do |kv|
        res << "\n #{kv}"
      end
      res << 'owners :'
      @key_owners.each do |k, v|
        res << "#{k} => #{v}"
      end
      res
    end
  end
end

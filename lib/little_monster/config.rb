module LittleMonster
  class Config
    attr_accessor :little_monster_api_url
    attr_accessor :api_request_retries

    def initialize(params = {})
      params.to_hash.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end
end

require_relative '../core/loggable'
require_relative '../core/api'

module LittleMonster::Core::Counters
  def increase_counter(counter_name, type, output = '')
    begin
      resp = LittleMonster::Core::API.put("/jobs/#{id}/counters/#{counter_name}",
                                          {body: {type: type, output: output}}, critical: true)
    rescue LittleMonster::APIUnreachableError => e
      # logger.error "[counter:#{counter_name}][type:#{type}][output:#[output]]: #{e.message}"
      raise ApiError
    end
    raise DuplicatedCounterError if resp.code == 412
    true
  end

  def counter(counter_name)
    resp = LittleMonster::Core::API.get("/jobs/#{id}/counters/#{counter_name}", critical: true)
    raise MissedCounterError if resp.code == 404
    resp.body
  end

  class MissedCounterError < StandardError
  end

  class DuplicatedCounterError < StandardError
  end

  class ApiError < StandardError
  end
end

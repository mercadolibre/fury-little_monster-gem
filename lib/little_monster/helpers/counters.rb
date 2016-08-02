require_relative '../core/loggable'
require_relative '../core/api'

module LittleMonster::Counters
  include LittleMonster::Core::Loggable
  def increase_counter(counter_name, type, output = '')
    begin
      resp = LittleMonster::Core::API.put("/jobs/#{@job_id}/counters/#{counter_name}",
                                          type: type, output: output)
    rescue LittleMonster::Core::API::FuryHttpApiError => e
      # logger.error "[counter:#{counter_name}][type:#{type}][output:#[output]]: #{e.message}"
      raise ApiError
    end
    raise DuplicatedCounterError if resp.code == 412
    true
  end

  class DuplicatedCounterError < StandardError
  end

  class ApiError < StandardError
  end
end

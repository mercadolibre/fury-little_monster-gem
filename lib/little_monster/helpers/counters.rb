require_relative '../core/loggable'
require_relative '../core/api'

module LittleMonster::Counters
  def increase_counter(counter_name, type, output = '')
    begin
      resp = LittleMonster::Core::API.put("/jobs/#{@job_id}/counters/#{counter_name}",
                                          type: type, output: output)
    rescue StandardError
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

require_relative '../core/loggable'
require_relative '../core/api'

module LittleMonster::Core::Counters
  def increase_counter(counter_name, unique_id, type, output = '')
    begin
      resp = LittleMonster::Core::API.put(
        "/jobs/#{job_id}/counters/#{counter_name}",
        { body: { type: type, unique_id: unique_id, output: output } },
        critical: true
      )
    rescue LittleMonster::APIUnreachableError => e
      logger.error "Could not increase counter #{counter_name}, Api unreachable"
      raise e
    end
    raise DuplicatedCounterError if resp.code == 412
    true
  end

  def counter(counter_name)
    resp = LittleMonster::Core::API.get("/jobs/#{job_id}/counters/#{counter_name}", {}, critical: true)
    raise MissedCounterError if resp.code == 404
    resp.body
  end

  def init_counters(*counter_names)
    counter_names.each do |counter_name|
      begin
        LittleMonster::Core::API.post(
          "/jobs/#{job_id}/counters/#{counter_name}",
          critical: true
        )
      rescue LittleMonster::APIUnreachableError => e
        logger.error "Could not init counter #{counter_name}, Api unreachable"
        raise e
      end
    end
    true
  end

  class MissedCounterError < StandardError
  end

  class DuplicatedCounterError < StandardError
  end
end

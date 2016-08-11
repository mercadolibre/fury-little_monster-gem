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

  def counter_endpoint(name)
    "#{LittleMonster.api_url.chomp('/')}/jobs/#{job_id}/counters/#{name}"
  end

  def init_counters(*counter_names)
    counter_names.each do |counter_name|
      resource = "/jobs/#{job_id}/counters"
      values = { body:{ name: counter_name } }
      begin
        res = LittleMonster::Core::API.post(resource, values, critical: true )
        raise MissedCounterError, "Could not post to #{resource}" if !res.success? && res.code != 409 # counter already exists
      rescue LittleMonster::APIUnreachableError => e
        logger.error "Could not init counter #{resource} with #{values} , Api unreachable"
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

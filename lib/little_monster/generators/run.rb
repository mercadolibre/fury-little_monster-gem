require 'bundler'
Bundler.require(:default,:development)

require_all "./jobs"
require_all "./tasks"

module LittleMonster
  class Run < Thor

    desc 'run a task','runner'
    argument :job, type: :string
    def start
      message={params:{"un_parametro":"un valor"},name: job}
      #on_message
      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end
  end
end

require 'thor'
require 'json'
require_relative './conf_gen'
require_relative './generate'

module LittleMonster
  class Cli < Thor

    desc 'show version','version'
    map %w[-v --version] => :version

    def version
      say '0.0.0'
    end

    desc 'exec <job>','runs a job'
    option :message,
      type: :hash,
      aliases: :m,
      default: {}

    method_option :message,
      aliases: '-m',
      type: :string,
      default: '{}',
      desc: 'Message that will be send as parameter (must be a JSON format)'

    def exec(job)
      require 'little_monster'
      require_relative "#{Dir.pwd}/config/application.rb"
      require_relative "#{Dir.pwd}/jobs/#{job}.rb"
      Dir["#{Dir.pwd}/tasks/#{job}/*.rb"].each {|file| require_relative file }

      msg=JSON.parse(options[:message])
      message={params:msg ,name: job}
      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end

    register(LittleMonster::ConfGen, 'init', 'init','Creates new Little Monster Schema app')
    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>...', 'Creates a job with his respective tasks.')
  end
end

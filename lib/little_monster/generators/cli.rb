require 'thor'
require_relative './conf_gen'
require_relative './generate'

module LittleMonster
  class Cli < Thor
    class_option :environment, 
      default: 'development', 
      type: :string,
      desc: 'environment',
      aliases: '-e'

    desc 'version','shows version'
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

    method_option :record_mode,
      aliases: '-r',
      type: :string,
      default: 'new_episodes',
      desc: 'Recording mocks mode  none|only_new|reload'

    def exec(job)
      ENV['LITTLE_MONSTER_ENV'] = option[:environment]
      require 'vcr'
      require 'little_monster'
      require_relative "#{Dir.pwd}/config/application.rb"
      require_relative "#{Dir.pwd}/jobs/#{job}.rb"
      require 'webmock'

      Dir["#{Dir.pwd}/tasks/#{job}/*.rb"].each {|file| require_relative file }
      VCR.configure do |config|
        config.cassette_library_dir = "mocks/vcr_cassettes"
        config.hook_into :webmock # or :fakeweb
      end

      vcr_mode = { 'none' => :none,
                   'only_new' => :new_episodes,
                   'reload' => :all }.fetch(option[:record_mode],:none)

      VCR.use_cassette(job.to_s, record: vcr_mode) do 
        msg=JSON.parse(options[:message])
        message={params:msg ,name: job}
        job = LittleMonster::Job::Factory.new(message).build
        job.run unless job.nil?
      end
    end

    register(LittleMonster::ConfGen, 'init', 'init','Creates new Little Monster Schema app')
    register(LittleMonster::Generate, 'generate', 'generate <job_name> <task_list>...', 'Creates a job with his respective tasks.')
  end
end

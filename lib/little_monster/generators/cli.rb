require 'thor'
require_relative './conf_gen'
require_relative './generate'

module LittleMonster
  class Cli < Thor
    desc 'show version', 'version'
    map %w(-v --version) => :version

    def version
      say LittleMonster::VERSION
    end

    desc 'exec <job>', 'runs a job'
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
                  enum: %w(none new reload),
                  default: 'none',
                  desc: 'Recording mocks mode  none|new|reload',
                  banner: 'Recording type could be none,new or reload on default assume none'

    def exec(job)
      ENV['LITTLE_MONSTER_ENV'] = options[:environment]
      require_relative "#{Dir.pwd}/config/application.rb"
      require 'webmock'
      require 'vcr'

      msg = MultiJson.load(options[:message], symbolize_keys: true)
      params = { data: { outputs: msg }, name: job }
      vcr_mode = { 'none' => :none,
                   'new' => :new_episodes,
                   'reload' => :all }.fetch(options[:record_mode], :none)
      VCR.configure do |config|
        config.cassette_library_dir = 'mocks/vcr_cassettes'
        config.hook_into :webmock # or :fakeweb
      end

      VCR.use_cassette(job.to_s, record: vcr_mode) do
        LittleMonster::Runner.new(params).run
      end
    end

    desc 'start', 'starts the little monster worker'
    option :daemonize,
           type: :boolean,
           default: false,
           aliases: :d

    def start
      require_relative "#{Dir.pwd}/config/application.rb"

      toiler_args = ['-C', "#{Dir.pwd}/config/toiler.yml"]
      toiler_args += ['-d', '-L', 'log/little_monster.log'] if options[:daemonize]
      Toiler::CLI.instance.run(toiler_args)
    end

    register(LittleMonster::ConfGen, 'init', 'init', 'Creates new Little Monster Schema app')
    register(LittleMonster::Generate,
             'generate',
             'generate <job_name> <task_list>...',
             'Creates a job with his respective tasks.')
  end
end

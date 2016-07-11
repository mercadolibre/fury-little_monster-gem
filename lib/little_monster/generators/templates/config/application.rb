require 'bundler'
Bundler.require(:default)

LittleMonster.configure do |conf|
  conf.api_url = "http://pepe.hongo.com"
  conf.default_request_retries = 3
  #conf.worker_concurrency = 200
  #conf.worker_queue = 'my_sqs_queue'
end

require_relative "enviroments/#{LittleMonster.env}"

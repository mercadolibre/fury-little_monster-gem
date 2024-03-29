require 'bundler'
Bundler.require(:default)

LittleMonster.configure do |conf|
  conf.api_url = 'http://pepe.hongo.com'
  conf.default_request_retries = 3
  # conf.worker_concurrency = 200
  # conf.worker_queue = 'my_sqs_queue'
  # conf.worker_provider = :aws
  # conf.worker_provider = :gcp
end

require_relative "environments/#{LittleMonster.env}"

Dir["#{Dir.pwd}/lib/**/*.rb"].sort.each { |file| require_relative file }
Dir["#{Dir.pwd}/jobs/**/*.rb"].sort.each { |file| require_relative file }
Dir["#{Dir.pwd}/tasks/**/*.rb"].sort.each { |file| require_relative file }

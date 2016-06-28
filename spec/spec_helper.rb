require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

ENV['RUBY_ENV'] = 'test'

require 'rspec'
require 'byebug'
require 'require_all'

require 'little_monster'
require 'little_monster/rspec'

require_rel '../jobs'
require_rel '../tasks'

require_rel 'mock'

RSpec.configure do |conf|
  conf.color = true
  conf.formatter = :documentation

  conf.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

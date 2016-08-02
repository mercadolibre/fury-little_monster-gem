require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

ENV['RUBY_ENV'] = 'test'

require 'rspec'
require 'byebug'
require 'require_all'
require "codeclimate-test-reporter"
require 'little_monster'
require 'little_monster/rspec'


require_rel 'mock'
CodeClimate::TestReporter.start

SimpleCov.start do
  add_filter 'spec'
  add_filter 'config'
  add_filter 'vendor'
end

RSpec.configure do |conf|
  conf.color = true
  conf.formatter = :documentation

  conf.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  conf.before :each do
    allow_any_instance_of(Kernel).to receive(:sleep)
  end
end


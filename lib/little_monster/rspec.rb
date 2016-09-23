module LittleMonster::RSpec
  require 'rspec'
  require 'rspec/expectations'

  require 'little_monster/rspec/helpers/job_helper'
  require 'little_monster/rspec/helpers/task_helper'

  # when required, this files define custom matchers on rspec
  require 'little_monster/rspec/matchers/have_ended_with_status'
  require 'little_monster/rspec/matchers/have_data'
  require 'little_monster/rspec/matchers/have_run'
  require 'little_monster/rspec/matchers/have_run_task'
  require 'little_monster/rspec/matchers/have_retries'
  require 'little_monster/rspec/matchers/have_callback_retries'

  # includes the run_job and run_task helper methods
  ::RSpec.configure do |config|
    config.include JobHelper
    config.include TaskHelper
    config.include Matchers
  end
end

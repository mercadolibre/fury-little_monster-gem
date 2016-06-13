require 'little_monster/core/errors/task_error' # must be required first to satisfy dependencies
require 'little_monster/core/errors/cancel_error'
require 'little_monster/core/errors/fatal_task_error'
require 'little_monster/core/errors/max_retries_error'

require 'little_monster/core/loggable' # must be required first to satisfy job and task dependencies
require 'little_monster/core/job'
require 'little_monster/core/task'

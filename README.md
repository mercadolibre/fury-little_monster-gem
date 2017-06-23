[![Build Status](https://travis-ci.org/mercadolibre/fury-little_monster-gem.svg?branch=travis-ci)](https://travis-ci.org/mercadolibre/fury-little_monster-gem)
[![Test Coverage](https://codeclimate.com/github/mercadolibre/fury-little_monster-gem/badges/coverage.svg)](https://codeclimate.com/github/mercadolibre/fury-little_monster-gem/coverage)
[![Code Climate](https://codeclimate.com/github/mercadolibre/fury-little_monster-gem/badges/gpa.svg)](https://codeclimate.com/github/mercadolibre/fury-little_monster-gem)
# fury-little_monster

## RSPEC Matchers

### Installation

in your spec_helper add the following line

```ruby
require 'little_monster/rspec'
```

### helpers

### generate_job
it takes a job and a hash of parameters and returns a fully configured job instance

#### generate_job with data
```ruby
generate_job :my_job, data: { a: :b }
```

#### generate_job with task mocked to fail
```ruby
generate_job :my_job, data: { a: :b }, fails: { task: :my_task, error: MyError.new }
```

#### generate_job with multiples tasks mocked to fail
```ruby
generate_job :my_job, data: { a: :b }, fails: [{ task: :my_task, error: MyError.new }, { task: :my_other_task, error: MyError.new }]
```

### run_job
given a generated job, it returns a JobResult object to make expectation about the run

### generate_task
it takes a task class or symbol and returns a fully configured task instance

#### generate_task with data
```ruby
generate_task MyJob::MyTask, data: { a: :b }
```

### matchers

### have_run

given a JobResult object expects the job to run that list of tasks
```ruby
expect(run_job(:my_job)).to have_run(:my_task, :my_other_task)
```

### have_run_task

given a JobResult object expects the job to run the a given task with a certain data
```ruby
expect(run_job(:my_job)).to have_run_task(:my_task).with_data(a: :b)
```

### have_ended_with_status

given a JobResult object expects the job have a given status after the run
```ruby
expect(run_job(:my_job)).to have_ended_with_status(:success)
```

### have_data

given checks a job or JobResult instance data
```ruby
expect(run_job(:my_job)).to have_ended_with_status(:success)
```
```ruby
expect(generate_job(:my_job)).to have_ended_with_status(:success)
```

### have_retries

given job instance, a class or a class symbol it expects the retries for that class
```ruby
expect(:my_job).to have_retries(3)
```

### have_callback_retries

given job instance, a class or a class symbol it expects the callback retries for that class
```ruby
expect(my_job).to have_callback_retries(10)
```

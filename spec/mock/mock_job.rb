class MockJob < LittleMonster::Job
  task_list :task_a, :task_b

  max_retries 4
end

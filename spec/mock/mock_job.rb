class MockJob < LittleMonster::Job
  task_list :task_a, :task_b

  retries 4
end

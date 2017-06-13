class MockJob < LittleMonster::Job
  task_list :task_a, :task_b, :task_c

  retries 4
end

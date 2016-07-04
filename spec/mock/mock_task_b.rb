class MockJob::TaskB < LittleMonster::Task
  def run
    output[:task_b] = 'task_b_finished'
  end
end

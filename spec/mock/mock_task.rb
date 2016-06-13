class MockJob::Task < LittleMonster::Task
  def run
    is_cancelled!
    'task_finished'
  end
end

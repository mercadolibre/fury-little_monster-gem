require 'spec_helper'

describe MockJob do
  it 'runs both its tasks' do
    expect(run_job(:mock_job, params: { a: :b })).to have_run(:task_a, :task_b)
  end

  it 'ends with status finished' do
    expect(run_job(:mock_job)).to have_ended_with_status :finished
  end

  it 'outputs the output of task_b' do
    expect(run_job(:mock_job)).to have_data({ task_b: 'task_b_finished' })
  end

  it 'ends with status failed if max retries is reached' do
    expect(run_job(:mock_job, fails: { task: :task_a, error: LittleMonster::TaskError })).to have_ended_with_status :pending
  end

  it 'runs task_b' do
    expect(run_job(:mock_job, params: { a: :b })).to have_run_task(:task_b)
      .with_params(a: :b)
      .with_output({ task_b: 'task_b_finished' })
  end
end

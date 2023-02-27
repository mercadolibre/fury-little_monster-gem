require 'spec_helper'

describe MockJobExtension do
  it 'runs both its tasks' do
    expect(run_job(:mock_job_extension, data: { a: :b })).to have_run(:task, :task_a, :task_b, :task_c)
  end

  it 'ends with status success' do
    expect(run_job(:mock_job_extension)).to have_ended_with_status :success
  end

  it 'outputs the data of task_b' do
    expect(run_job(:mock_job_extension)).to have_data({ task_b: 'task_b_finished_by_extension' })
  end

  it 'ends with status failed if max retries is reached' do
    expect(run_job(:mock_job_extension,
                   fails: { task: :task_a, error: LittleMonster::TaskError })).to have_ended_with_status :error
  end

  it 'has 4 retries' do
    expect(:mock_job_extension).to have_retries(4)
  end

  it 'has 4 callback retries' do
    expect(:mock_job_extension).to have_callback_retries(4)
  end

  it 'runs task_b' do
    expect(run_job(:mock_job_extension)).to have_run_task(:task_b)
      .with_data({ task_b: 'task_b_finished_by_extension' })
  end
end

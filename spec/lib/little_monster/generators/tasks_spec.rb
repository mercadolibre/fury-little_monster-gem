require 'spec_helper'

describe LittleMonster::Generators::Tasks do
  before :each do
    double(FileUtils)
    double(File)
    @gen = described_class.new('fake_job', 'fake_task_1', 'fake_task_2')
  end

  describe '.generate_tasks_files' do
    before(:each) do
      allow(File).to receive(:exist?).and_return true
    end

    it 'calls tasks templates two times' do
      fake_tilt = double('')
      allow(fake_tilt).to receive(:render)
      expect(Tilt).to receive(:new).and_return(fake_tilt).twice
      @gen.generate_tasks_files
    end

    it 'renders two templates' do
      fake_tilt = double('')
      allow(Tilt).to receive(:new).and_return(fake_tilt)
      expect(fake_tilt).to receive(:render).twice
      @gen.generate_tasks_files
    end
  end

  describe '.generate_test_files' do
    before(:each) do
      allow(File).to receive(:exist?).and_return true
    end

    it 'calls test templates two times' do
      fake_tilt = double('')
      allow(fake_tilt).to receive(:render)
      expect(Tilt).to receive(:new).and_return(fake_tilt).twice
      @gen.generate_tests_files
    end
    it 'calls test templates render two times' do
      fake_tilt = double('')
      allow(Tilt).to receive(:new).and_return(fake_tilt)
      expect(fake_tilt).to receive(:render).twice
      @gen.generate_tests_files
    end
  end
end

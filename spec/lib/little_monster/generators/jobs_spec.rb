require 'spec_helper'

describe LittleMonster::Generators::Jobs do
  before :each do
    double(FileUtils)
    double(File)
    @gen = described_class.new('fake_job', 'fake_task_1', 'fake_task_2')
  end

  describe '.generate_jobs_files' do
    before(:each) do
      allow(File).to receive(:exist?).and_return true
    end

    it 'calls job template' do
      fake_tilt = double('')
      allow(fake_tilt).to receive(:render)
      expect(Tilt).to receive(:new).and_return(fake_tilt).once
      @gen.generate_jobs_files
    end

    it 'renders just one job template' do
      fake_tilt = double('')
      allow(Tilt).to receive(:new).and_return(fake_tilt)
      expect(fake_tilt).to receive(:render).once
      @gen.generate_jobs_files
    end
  end

  describe '.generate_test_files' do
    before(:each) do
      allow(File).to receive(:exist?).and_return true
    end

    it 'calls test templates one time' do
      fake_tilt = double('')
      allow(fake_tilt).to receive(:render)
      expect(Tilt).to receive(:new).and_return(fake_tilt).once
      @gen.generate_test_files
    end
    it 'calls test templates render two times' do
      fake_tilt = double('')
      allow(Tilt).to receive(:new).and_return(fake_tilt)
      expect(fake_tilt).to receive(:render).once
      @gen.generate_test_files
    end
  end
end

require 'spec_helper'

describe LittleMonster::Generators::FileManager do
  before :each do
    double(FileUtils)
    double(File)
    @fm = described_class.new
  end

  describe '.prepare_folders' do
    it 'creates folder and spec folder folder' do
      expect(FileUtils).to receive(:mkdir_p).twice
      @fm.prepare_folders(['testing'])
    end
  end

  describe '.create_file' do
    it 'not create or overwrite any file if it allready exists' do
      allow(File).to receive(:exist?).and_return(true)
      expect(@fm.create_file('/tmp/fake', 'out')).to eq(false)
    end

    it 'creates files if doesn\'t exist' do
      file = double('file')
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:open).and_yield(file)
      allow(file).to receive(:write)
      allow(file).to receive(:flush)
      expect(@fm.create_file('/tmp/fake', 'out')).to eq(true)
    end
  end
end

require 'spec_helper'

describe LittleMonster::Tiger::Cache do
  subject(:cache) { described_class }

  let(:key) { SecureRandom.uuid }

  before do
    LittleMonster::Tiger::Cache.instance.cache.clear
    cache.instance.set(:key, key)
  end

  describe '.set' do
    context 'when set a key and value' do
      before do
        cache.instance.set(:key, key)
      end

      it 'store that value for that key' do
        expect(cache.instance.get(:key)).to eq(key)
      end
    end

    context 'when set a key, value and expires' do
      let(:expires) { 1 }

      before do
        cache.instance.set(:key, key, expires)
      end

      it 'store that value for that key for `expires` seconds' do
        expect(cache.instance.get(:key)).to eq(key)
        Kernel.sleep(expires + 1)
        expect(cache.instance.get(:key)).to be_nil
      end
    end
  end

  describe '.get' do
    context 'when get from a not exist key' do
      it 'return nil' do
        expect(cache.instance.get(:foo)).to be_nil
      end
    end
  end

  describe '.clear' do
    context 'when get a exist key after clear cache' do

      before do
        LittleMonster::Tiger::Cache.instance.cache.clear
      end

      it 'return nil' do
        expect(cache.instance.get(:key)).to be_nil
      end
    end
  end
end

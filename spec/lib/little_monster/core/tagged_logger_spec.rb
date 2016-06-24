require 'spec_helper'

describe LittleMonster::Core::TaggedLogger do
  subject { described_class.new }
  let(:key) { :info }
  let(:tags) { { a: :b, c: :d } }
  let(:message) { 'message' }

  describe '::LEVELS' do
    specify { expect(described_class::LEVELS).to eq([:unknown, :fatal, :error, :warn, :info, :debug]) }
  end

  describe '::tags_to_string' do
    context 'given a hash' do
      it 'return hash converted to kibana tags string format' do
        expect(described_class.tags_to_string tags).to eq('[a:b][c:d]')
      end
    end
  end

  describe '#initialize' do

    it 'sets tags instance variable to a hash' do
      expect(subject.tags.class).to be Hash
    end

    it 'sets tags to a hash with empty hash as deafult' do
      expect(subject.tags.default).to eq({})
    end
  end

  describe '#tags_for' do
    context 'given a key and a hash' do

      it 'sets the given key to the given hash in @tags' do
        subject.tags_for key, tags
        expect(subject.tags[key]).to eq(tags)
      end
    end
  end

  describe '#default_tags' do
    context 'given a hash' do
      it 'sets the hash under the default key in @tags' do
        subject.default_tags hash
        expect(subject.tags[:default]).to eq(hash)
      end
    end
  end

  describe '#tag_message' do
    let(:info_tags) {  { x: :y } }
    let(:resulting_tags) { tags.merge(info_tags) }

    before :each do
      subject.default_tags tags
      subject.tags_for :info, info_tags
    end

    context 'given a level key and a message' do
      it 'returns default tags merged with tags and message' do
        expect(subject.tag_message key, message).to eq("#{subject.tags_to_string resulting_tags} -- #{message}")
      end
    end
  end
end


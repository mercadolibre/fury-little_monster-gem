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

  describe '#default_tags=' do
    context 'given a hash' do
      it 'sets the hash under the default key in @tags' do
        subject.default_tags = hash
        expect(subject.tags[:default]).to eq(hash)
      end
    end
  end

  describe '#tag_message' do
    let(:info_tags) {  { x: :y } }
    let(:resulting_tags) { tags.merge(info_tags) }

    context 'given a level key and a message' do
      context 'if there are no tags set' do
        it 'returns message' do
          expect(subject.tag_message key, message).to eq(message)
        end
      end

      context 'if there are tags set' do
        before :each do
          subject.default_tags = tags
          subject.tags_for :info, info_tags
        end

        context 'if parent_logger is nil' do
          it 'returns default tags merged with tags and message' do
            expect(subject.tag_message key, message).to eq("#{subject.tags_to_string resulting_tags} -- #{message}")
          end
        end

        context 'if parent_logger is not nil' do
          let(:parent_logger) { double(tag_message: 'parent_retagged_message') }

          before :each do
            subject.parent_logger = parent_logger
          end

          it 'returns default tags merged with tags and message' do
            expect(subject.tag_message key, message).to eq("#{parent_logger.tag_message}#{message}")
          end
        end
      end
    end
  end

  describe '#log_tags' do
    let(:level) { :info }
    let(:tags) { { a: :b } }

    it 'calls level log with hash converted to string'  do
      allow(LittleMonster.logger).to receive(level)
      subject.log_tags(level, tags)
      expect(LittleMonster.logger).to have_received(level).with('[a:b]')
    end
  end

  describe '#default_tags' do
    specify { expect(subject.default_tags).to eq(subject.tags[:default]) }
  end

  describe '#method_missing' do
    context 'if method ends with tags=' do
      before :each do
        allow(subject).to receive(:tags_for)
      end

      context 'if method begins with a level' do
        let(:tags) { { a: :b } }

        it 'calls tags_for with level and args' do
          subject.info_tags = tags
          expect(subject).to have_received(:tags_for).with(:info, tags)
        end
      end

      context 'if method does not begin with a level' do
        it 'raises NoMethodError' do
          expect { subject.unexisting_level_tags = {} }.to raise_error(NoMethodError)
        end
      end
    end

    context 'if method ends with tags' do
      context 'if method begins with a level' do
        let(:tags) { { a: :b } }

        it 'returns the tags for that level' do
          subject.tags_for :info, tags
          expect(subject.info_tags).to eq(tags)
        end
      end

      context 'if method does not begin with a level' do
        it 'raises NoMethodError' do
          expect { subject.unexisting_level_tags }.to raise_error(NoMethodError)
        end
      end
    end

    context 'if method is a level' do
      let(:tagged_message) { double }

      it 'calls level log with tagged_message' do
        allow(subject).to receive(:tag_message).and_return(tagged_message)
        allow(LittleMonster.logger).to receive(:info)

        subject.info 'message'
        expect(LittleMonster.logger).to have_received(:info).with(tagged_message)
      end
    end

    context 'otherwise' do
      it 'raises NoMethodError' do
        expect { subject.not_existing_method }.to raise_error(NoMethodError)
      end
    end
  end
end

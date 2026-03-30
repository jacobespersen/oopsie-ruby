# frozen_string_literal: true

RSpec.describe Oopsie::ExceptionChainBuilder do
  describe '.build' do
    it 'builds chain from a single exception' do
      error = RuntimeError.new('boom')
      error.set_backtrace(["app/models/user.rb:42:in `find_or_raise'"])

      chain = described_class.build(error)

      expect(chain.length).to eq(1)
      expect(chain[0][:type]).to eq('RuntimeError')
      expect(chain[0][:value]).to include('boom')
      expect(chain[0][:mechanism]).to eq({ type: 'generic', handled: false })
    end

    it 'builds chain from chained exceptions (root cause first)' do
      chain = nil
      begin
        begin
          raise ArgumentError, 'root cause'
        rescue ArgumentError
          raise 'outer error'
        end
      rescue RuntimeError => e
        chain = described_class.build(e)
      end

      expect(chain.length).to eq(2)
      expect(chain[0][:type]).to eq('ArgumentError')
      expect(chain[0][:value]).to include('root cause')
      expect(chain[0][:mechanism]).to eq({ type: 'chained', handled: false })
      expect(chain[1][:type]).to eq('RuntimeError')
      expect(chain[1][:value]).to include('outer error')
      expect(chain[1][:mechanism]).to eq({ type: 'generic', handled: false })
    end

    it 'caps chain at 20 entries' do
      chain = build_deep_chain(25)
      result = described_class.build(chain)

      expect(result.length).to be <= 20
    end

    it 'handles exception without backtrace' do
      error = RuntimeError.new('no trace')

      chain = described_class.build(error)

      expect(chain.length).to eq(1)
      expect(chain[0][:stacktrace]).to eq([])
    end

    it 'handles frozen exceptions' do
      error = RuntimeError.new('frozen')
      error.set_backtrace(["app/test.rb:1:in `run'"])
      error.freeze

      chain = described_class.build(error)

      expect(chain.length).to eq(1)
      expect(chain[0][:type]).to eq('RuntimeError')
    end

    it 'terminates on circular cause chains' do
      a = RuntimeError.new('A')
      a.set_backtrace(["test.rb:1:in `a'"])
      b = RuntimeError.new('B')
      b.set_backtrace(["test.rb:2:in `b'"])

      allow(a).to receive(:cause).and_return(b)
      allow(b).to receive(:cause).and_return(a)

      chain = described_class.build(a)

      expect(chain.length).to eq(2)
      expect(chain.map { |e| e[:value] }).to include(match(/A/), match(/B/))
    end

    it 'deduplicates shared backtrace objects across chained exceptions' do
      backtrace = ["app/test.rb:1:in `run'"]
      inner = RuntimeError.new('inner')
      inner.set_backtrace(backtrace)
      outer = RuntimeError.new('outer')
      outer.set_backtrace(backtrace) # same array object

      # Stub cause chain: outer.cause => inner
      allow(outer).to receive(:cause).and_return(inner)
      allow(inner).to receive(:cause).and_return(nil)

      chain = described_class.build(outer)

      expect(chain[0][:stacktrace]).to equal(chain[1][:stacktrace])
    end
  end

  describe 'message handling' do
    it 'uses detailed_message when available (Ruby 3.2+)' do
      error = RuntimeError.new('short')
      error.set_backtrace(["test.rb:1:in `x'"])
      allow(error).to receive(:detailed_message).with(highlight: false).and_return('short (RuntimeError)')

      chain = described_class.build(error)

      expect(chain[0][:value]).to eq('short (RuntimeError)')
    end

    it 'scrubs invalid UTF-8 bytes in messages' do
      bad_message = "bad bytes: \xFF\xFE".dup.force_encoding('ASCII-8BIT')
      error = RuntimeError.new(bad_message)
      error.set_backtrace(["test.rb:1:in `x'"])

      chain = described_class.build(error)

      expect(chain[0][:value].encoding).to eq(Encoding::UTF_8)
      expect(chain[0][:value]).to be_valid_encoding
    end

    it 'handles non-string messages' do
      error = RuntimeError.new('test')
      error.set_backtrace(["test.rb:1:in `x'"])
      allow(error).to receive(:detailed_message).with(highlight: false).and_return(nil)

      chain = described_class.build(error)

      expect(chain[0][:value]).to be_a(String)
    end
  end

  describe 'frame parsing' do
    it 'parses standard backtrace lines' do
      error = RuntimeError.new('test')
      error.set_backtrace(["app/models/user.rb:42:in `find_or_raise'"])

      chain = described_class.build(error)
      frame = chain[0][:stacktrace][0]

      expect(frame[:file]).to eq('app/models/user.rb')
      expect(frame[:function]).to eq('find_or_raise')
      expect(frame[:lineno]).to eq(42)
      expect(frame[:in_app]).to be true
    end

    it 'marks gem frames as not in_app' do
      error = RuntimeError.new('test')
      error.set_backtrace(["/ruby/gems/3.4.0/gems/activerecord-7.0/lib/active_record/base.rb:100:in `find'"])

      chain = described_class.build(error)
      frame = chain[0][:stacktrace][0]

      expect(frame[:in_app]).to be false
    end

    it 'marks vendor frames as not in_app' do
      error = RuntimeError.new('test')
      error.set_backtrace(["/app/vendor/bundle/gems/pg-1.5/lib/pg.rb:10:in `connect'"])

      chain = described_class.build(error)
      frame = chain[0][:stacktrace][0]

      expect(frame[:in_app]).to be false
    end

    it 'marks internal frames as not in_app' do
      error = RuntimeError.new('test')
      error.set_backtrace(["<internal:kernel>:187:in `loop'"])

      chain = described_class.build(error)
      frame = chain[0][:stacktrace][0]

      expect(frame[:in_app]).to be false
    end

    it 'handles unparseable backtrace lines gracefully' do
      error = RuntimeError.new('test')
      error.set_backtrace(['NativeMethod:unknown'])

      chain = described_class.build(error)
      frame = chain[0][:stacktrace][0]

      expect(frame[:file]).to eq('NativeMethod:unknown')
      expect(frame[:function]).to eq('')
      expect(frame[:lineno]).to eq(0)
    end

    it 'caps frames at 100 per exception' do
      error = RuntimeError.new('test')
      error.set_backtrace(150.times.map { |i| "file.rb:#{i}:in `method'" })

      chain = described_class.build(error)

      expect(chain[0][:stacktrace].length).to eq(100)
    end
  end

  def build_deep_chain(depth) # rubocop:disable Metrics/MethodLength
    if depth <= 1
      begin
        raise 'error 0'
      rescue RuntimeError => e
        return e
      end
    end

    begin
      begin
        raise build_deep_chain(depth - 1)
      rescue RuntimeError
        raise "error #{depth}"
      end
    rescue RuntimeError => e
      e
    end
  end
end

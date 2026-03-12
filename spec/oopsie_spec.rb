# frozen_string_literal: true

RSpec.describe Oopsie do
  before do
    Oopsie.configure do |config|
      config.api_key = 'test-key'
      config.endpoint = 'https://oopsie.example.com'
    end
  end

  describe '.report' do
    it 'sends error_class, message, and stack_trace from an exception' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .with(body: hash_including(
               'error_class' => 'RuntimeError',
               'message' => 'test error'
             ))
             .to_return(status: 202, body: '{"status":"accepted"}')

      begin
        raise 'test error'
      rescue StandardError => e
        Oopsie.report(e)
      end

      expect(stub).to have_been_requested
    end

    it 'includes backtrace as stack_trace' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .with { |req| JSON.parse(req.body)['stack_trace']&.include?('oopsie_spec.rb') }
             .to_return(status: 202, body: '{"status":"accepted"}')

      begin
        raise 'with backtrace'
      rescue StandardError => e
        Oopsie.report(e)
      end

      expect(stub).to have_been_requested
    end

    it 'handles exceptions without backtrace' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .with(body: hash_including('stack_trace' => nil))
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('no backtrace')
      Oopsie.report(error)

      expect(stub).to have_been_requested
    end

    it 'does not raise when configuration is invalid' do
      Oopsie.reset_configuration!

      expect { Oopsie.report(RuntimeError.new('oops')) }.not_to raise_error
    end

    it 'calls on_error when configuration is invalid' do
      Oopsie.reset_configuration!
      errors = []
      Oopsie.configure do |config|
        config.on_error = ->(e) { errors << e }
      end

      Oopsie.report(RuntimeError.new('oops'))

      expect(errors.length).to eq(1)
      expect(errors.first).to be_a(Oopsie::ConfigurationError)
    end

    context 'deduplication' do
      it 'reports the same exception instance only once' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        error = RuntimeError.new('duplicate')
        error.set_backtrace(['test:1'])

        Oopsie.report(error)
        Oopsie.report(error)

        expect(stub).to have_been_requested.once
      end

      it 'reports different instances of the same class independently' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        error1 = RuntimeError.new('first')
        error1.set_backtrace(['test:1'])
        error2 = RuntimeError.new('second')
        error2.set_backtrace(['test:2'])

        Oopsie.report(error1)
        Oopsie.report(error2)

        expect(stub).to have_been_requested.twice
      end

      it 'reports frozen exceptions every time (cannot tag frozen objects)' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        error = RuntimeError.new('frozen error')
        error.set_backtrace(['test:1'])
        error.freeze

        Oopsie.report(error)
        Oopsie.report(error)

        expect(stub).to have_been_requested.twice
      end
    end

    context 'with ignored_exceptions configured' do
      before do
        Oopsie.configure do |config|
          config.ignored_exceptions = [ArgumentError]
        end
      end

      it 'does not report ignored exception classes' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        begin
          raise ArgumentError, 'bad arg'
        rescue StandardError => e
          Oopsie.report(e)
        end

        expect(stub).not_to have_been_requested
      end

      it 'does not report subclasses of ignored exceptions' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        custom_error = Class.new(ArgumentError)

        begin
          raise custom_error, 'subclass error'
        rescue StandardError => e
          Oopsie.report(e)
        end

        expect(stub).not_to have_been_requested
      end

      it 'still reports non-ignored exceptions' do
        stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
               .to_return(status: 202, body: '{"status":"accepted"}')

        begin
          raise 'not ignored'
        rescue StandardError => e
          Oopsie.report(e)
        end

        expect(stub).to have_been_requested
      end
    end
  end
end

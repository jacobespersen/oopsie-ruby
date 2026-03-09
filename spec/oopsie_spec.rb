# frozen_string_literal: true

RSpec.describe Oopsie do
  before do
    Oopsie.configure do |config|
      config.api_key = "test-key"
      config.endpoint = "https://oopsie.example.com"
    end
  end

  describe ".report" do
    it "sends error_class, message, and stack_trace from an exception" do
      stub = stub_request(:post, "https://oopsie.example.com/api/v1/errors")
        .with(body: hash_including(
          "error_class" => "RuntimeError",
          "message" => "test error"
        ))
        .to_return(status: 202, body: '{"status":"accepted"}')

      begin
        raise RuntimeError, "test error"
      rescue => e
        Oopsie.report(e)
      end

      expect(stub).to have_been_requested
    end

    it "includes backtrace as stack_trace" do
      stub = stub_request(:post, "https://oopsie.example.com/api/v1/errors")
        .with { |req| JSON.parse(req.body)["stack_trace"]&.include?("oopsie_spec.rb") }
        .to_return(status: 202, body: '{"status":"accepted"}')

      begin
        raise "with backtrace"
      rescue => e
        Oopsie.report(e)
      end

      expect(stub).to have_been_requested
    end

    it "handles exceptions without backtrace" do
      stub = stub_request(:post, "https://oopsie.example.com/api/v1/errors")
        .with(body: hash_including("stack_trace" => nil))
        .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new("no backtrace")
      Oopsie.report(error)

      expect(stub).to have_been_requested
    end

    it "does not raise when configuration is invalid" do
      Oopsie.reset_configuration!

      expect { Oopsie.report(RuntimeError.new("oops")) }.not_to raise_error
    end

    it "calls on_error when configuration is invalid" do
      Oopsie.reset_configuration!
      errors = []
      Oopsie.configure do |config|
        config.on_error = ->(e) { errors << e }
      end

      Oopsie.report(RuntimeError.new("oops"))

      expect(errors.length).to eq(1)
      expect(errors.first).to be_a(Oopsie::ConfigurationError)
    end
  end
end

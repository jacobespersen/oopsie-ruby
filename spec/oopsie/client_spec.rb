# frozen_string_literal: true

RSpec.describe Oopsie::Client do
  let(:endpoint) { "https://oopsie.example.com" }
  let(:api_key) { "test-api-key-123" }

  before do
    Oopsie.configure do |config|
      config.api_key = api_key
      config.endpoint = endpoint
    end
  end

  describe "#send_error" do
    it "POSTs to /api/v1/errors with correct payload" do
      stub = stub_request(:post, "#{endpoint}/api/v1/errors")
        .with(
          body: { error_class: "RuntimeError", message: "something broke", stack_trace: "file.rb:1:in `method'" },
          headers: {
            "Authorization" => "Bearer #{api_key}",
            "Content-Type" => "application/json"
          }
        )
        .to_return(status: 202, body: '{"status":"accepted"}')

      client = described_class.new(Oopsie.configuration)
      client.send_error(
        error_class: "RuntimeError",
        message: "something broke",
        stack_trace: "file.rb:1:in `method'"
      )

      expect(stub).to have_been_requested
    end

    it "sends null stack_trace when not provided" do
      stub = stub_request(:post, "#{endpoint}/api/v1/errors")
        .with(body: { error_class: "RuntimeError", message: "oops", stack_trace: nil })
        .to_return(status: 202, body: '{"status":"accepted"}')

      client = described_class.new(Oopsie.configuration)
      client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)

      expect(stub).to have_been_requested
    end

    it "does not raise on HTTP error" do
      stub_request(:post, "#{endpoint}/api/v1/errors").to_return(status: 500)

      client = described_class.new(Oopsie.configuration)
      expect {
        client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)
      }.not_to raise_error
    end

    it "calls on_error callback on HTTP error" do
      stub_request(:post, "#{endpoint}/api/v1/errors").to_return(status: 500)

      errors = []
      Oopsie.configuration.on_error = ->(e) { errors << e }

      client = described_class.new(Oopsie.configuration)
      client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)

      expect(errors.length).to eq(1)
      expect(errors.first).to be_a(Oopsie::DeliveryError)
    end

    it "does not raise on network error" do
      stub_request(:post, "#{endpoint}/api/v1/errors").to_timeout

      client = described_class.new(Oopsie.configuration)
      expect {
        client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)
      }.not_to raise_error
    end

    it "calls on_error callback on network error" do
      stub_request(:post, "#{endpoint}/api/v1/errors").to_timeout

      errors = []
      Oopsie.configuration.on_error = ->(e) { errors << e }

      client = described_class.new(Oopsie.configuration)
      client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)

      expect(errors.length).to eq(1)
    end

    it "swallows errors from on_error callback itself" do
      stub_request(:post, "#{endpoint}/api/v1/errors").to_return(status: 500)

      Oopsie.configuration.on_error = ->(_e) { raise "callback exploded" }

      client = described_class.new(Oopsie.configuration)
      expect {
        client.send_error(error_class: "RuntimeError", message: "oops", stack_trace: nil)
      }.not_to raise_error
    end
  end
end

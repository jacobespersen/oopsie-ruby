# frozen_string_literal: true

require "rack/test"

RSpec.describe Oopsie::Middleware do
  include Rack::Test::Methods

  let(:error) { RuntimeError.new("app exploded") }

  let(:inner_app) do
    err = error
    ->(_env) { raise err }
  end

  let(:ok_app) do
    ->(_env) { [200, { "content-type" => "text/plain" }, ["OK"]] }
  end

  before do
    Oopsie.configure do |config|
      config.api_key = "test-key"
      config.endpoint = "https://oopsie.example.com"
    end

    stub_request(:post, "https://oopsie.example.com/api/v1/errors")
      .to_return(status: 202, body: '{"status":"accepted"}')
  end

  describe "when the app raises" do
    let(:app) { described_class.new(inner_app) }

    it "re-raises the original exception" do
      expect { get "/" }.to raise_error(RuntimeError, "app exploded")
    end

    it "reports the error to Oopsie" do
      begin
        get "/"
      rescue RuntimeError
        # expected
      end

      expect(
        a_request(:post, "https://oopsie.example.com/api/v1/errors")
          .with(body: hash_including("error_class" => "RuntimeError", "message" => "app exploded"))
      ).to have_been_made
    end
  end

  describe "when the app succeeds" do
    let(:app) { described_class.new(ok_app) }

    it "returns the response normally" do
      get "/"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq("OK")
    end

    it "does not report anything" do
      get "/"
      expect(a_request(:post, "https://oopsie.example.com/api/v1/errors")).not_to have_been_made
    end
  end

  describe "when Oopsie.report fails" do
    let(:app) { described_class.new(inner_app) }

    it "still re-raises the original exception" do
      stub_request(:post, "https://oopsie.example.com/api/v1/errors").to_timeout

      expect { get "/" }.to raise_error(RuntimeError, "app exploded")
    end
  end
end

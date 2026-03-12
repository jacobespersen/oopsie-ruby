# frozen_string_literal: true

require 'spec_helper'
require 'oopsie/sidekiq'

RSpec.describe Oopsie::Sidekiq::ErrorHandler do
  before do
    Oopsie.configure do |config|
      config.api_key = 'test-key'
      config.endpoint = 'https://oopsie.example.com'
    end
  end

  describe '#call' do
    it 'reports the exception via Oopsie.report' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('job failed')
      error.set_backtrace(['app/jobs/test:1'])

      described_class.new.call(error, { job: 'TestJob' })

      expect(stub).to have_been_requested.once
    end

    it 'accepts extra arguments for Sidekiq 7+ compatibility' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('job failed')
      error.set_backtrace(['app/jobs/test:1'])

      expect { described_class.new.call(error, {}, :extra_config) }.not_to raise_error

      expect(stub).to have_been_requested.once
    end
  end
end

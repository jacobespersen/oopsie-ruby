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

      described_class.new.call(error, { job: { 'class' => 'TestJob', 'queue' => 'default', 'jid' => 'abc' } })

      expect(stub).to have_been_requested.once
    end

    it 'includes worker execution_context in the report' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .with do |req|
               ctx = JSON.parse(req.body)['execution_context']
               ctx['type'] == 'worker' &&
                 ctx['description'] == 'HardWorker#perform' &&
                 ctx['data']['job_class'] == 'HardWorker' &&
                 ctx['data']['queue'] == 'critical'
             end
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('job failed')
      error.set_backtrace(['app/jobs/test:1'])

      described_class.new.call(error, { job: { 'class' => 'HardWorker', 'queue' => 'critical', 'jid' => 'xyz' } })

      expect(stub).to have_been_requested.once
    end

    it 'handles empty context hash gracefully' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('job failed')
      error.set_backtrace(['app/jobs/test:1'])

      expect { described_class.new.call(error, {}) }.not_to raise_error
      expect(stub).to have_been_requested.once
    end

    it 'handles string-keyed context hash' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .with do |req|
               ctx = JSON.parse(req.body)['execution_context']
               ctx['type'] == 'worker' &&
                 ctx['data']['job_class'] == 'StringKeyWorker'
             end
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('job failed')
      error.set_backtrace(['app/jobs/test:1'])

      described_class.new.call(error, { 'job' => { 'class' => 'StringKeyWorker', 'queue' => 'default' } })

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

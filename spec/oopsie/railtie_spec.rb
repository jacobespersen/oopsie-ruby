# frozen_string_literal: true

require 'spec_helper'
require 'oopsie/railtie'

RSpec.describe Oopsie::Railtie do
  before do
    Oopsie.configure do |config|
      config.api_key = 'test-key'
      config.endpoint = 'https://oopsie.example.com'
    end
  end

  it 'is a Rails::Railtie subclass' do
    expect(described_class.superclass).to eq(Rails::Railtie)
  end

  describe 'process_action.action_controller subscriber' do
    # Manually subscribe using the same logic as the Railtie initializer,
    # since initializers only run during Rails.application.initialize!
    before do
      @subscriber = ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
        if (exception = event.payload[:exception_object])
          Oopsie.report(exception)
        end
      end
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@subscriber)
    end

    it 'reports exceptions from the notification payload' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .to_return(status: 202, body: '{"status":"accepted"}')

      error = RuntimeError.new('controller error')
      error.set_backtrace(['app/controllers/test:1'])

      ActiveSupport::Notifications.instrument('process_action.action_controller',
                                              exception_object: error)

      expect(stub).to have_been_requested.once
    end

    it 'does not report when no exception in payload' do
      stub = stub_request(:post, 'https://oopsie.example.com/api/v1/errors')
             .to_return(status: 202, body: '{"status":"accepted"}')

      ActiveSupport::Notifications.instrument('process_action.action_controller',
                                              status: 200)

      expect(stub).not_to have_been_requested
    end
  end
end

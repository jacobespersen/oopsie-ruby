# frozen_string_literal: true

require 'rails/railtie'
require 'active_support/isolated_execution_state'
require 'active_support/notifications'

module Oopsie
  class Railtie < Rails::Railtie
    initializer 'oopsie.middleware' do |app|
      app.middleware.insert_before ActionDispatch::ShowExceptions, Oopsie::Middleware
    end

    initializer 'oopsie.subscribe' do
      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
        if (exception = event.payload[:exception_object])
          Oopsie.report(exception)
        end
      end
    end
  end
end

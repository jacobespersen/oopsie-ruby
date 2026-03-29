# frozen_string_literal: true

require 'rails/railtie'
require 'active_support/isolated_execution_state'
require 'active_support/notifications'

module Oopsie
  class Railtie < Rails::Railtie
    initializer 'oopsie.middleware' do |app|
      app.middleware.insert_before ActionDispatch::ShowExceptions, Oopsie::Middleware
    end

    # Catches exceptions handled within the controller (e.g., via rescue_from)
    # that don't propagate up to the Rack middleware.
    initializer 'oopsie.subscribe' do
      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
        if (exception = event.payload[:exception_object])
          context = begin
            env = event.payload[:headers]&.env || {}
            Oopsie::ContextBuilder.from_rack_env(env)
          rescue StandardError
            nil
          end
          Oopsie.report(exception, context: context)
        end
      end
    end
  end
end

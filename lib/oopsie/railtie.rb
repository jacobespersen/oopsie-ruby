# frozen_string_literal: true

require 'rails/railtie'
require 'active_support/isolated_execution_state'
require 'active_support/notifications'

module Oopsie
  class Railtie < Rails::Railtie
    initializer 'oopsie.middleware' do |app|
      app.middleware.insert_before ActionDispatch::ShowExceptions, Oopsie::Middleware
    end

    # Catches exceptions raised during controller actions that Rails surfaces in
    # the notification payload. Exceptions fully handled by rescue_from will NOT appear here.
    initializer 'oopsie.subscribe' do
      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |event|
        if (exception = event.payload[:exception_object])
          context = begin
            env = event.payload[:headers]&.env
            env ? Oopsie::ContextBuilder.from_rack_env(env) : nil
          rescue StandardError => e
            Oopsie.safely_notify_error(e)
            nil
          end
          Oopsie.report(exception, context: context)
        end
      end
    end
  end
end

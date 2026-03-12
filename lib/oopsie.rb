# frozen_string_literal: true

require_relative 'oopsie/version'
require_relative 'oopsie/configuration'
require_relative 'oopsie/client'
require_relative 'oopsie/middleware'
require_relative 'oopsie/railtie' if defined?(Rails::Railtie)

module Oopsie
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def report(exception)
      return if skip_report?(exception)

      tag_reported(exception)
      configuration.validate!
      Client.new(configuration).send_error(
        error_class: exception.class.name,
        message: exception.message,
        stack_trace: exception.backtrace&.join("\n")
      )
    rescue StandardError => e
      safely_notify_error(e)
    end

    private

    def skip_report?(exception)
      configuration.ignored_exceptions.any? { |klass| exception.is_a?(klass) } ||
        exception.instance_variable_get(:@_oopsie_reported)
    end

    def tag_reported(exception)
      exception.instance_variable_set(:@_oopsie_reported, true)
    rescue FrozenError
      # Frozen exceptions can't be tagged — skip dedup, proceed with reporting
    end

    def safely_notify_error(error)
      configuration.on_error&.call(error)
    rescue StandardError
      # Never crash the host app
    end
  end
end

# frozen_string_literal: true

require_relative 'oopsie/version'
require_relative 'oopsie/configuration'
require_relative 'oopsie/client'
require_relative 'oopsie/middleware'

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
      return if configuration.ignored_exceptions.any? { |klass| exception.is_a?(klass) }

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

    def safely_notify_error(error)
      configuration.on_error&.call(error)
    rescue StandardError
      # Never crash the host app
    end
  end
end

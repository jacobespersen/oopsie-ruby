# frozen_string_literal: true

require_relative "oopsie/version"
require_relative "oopsie/configuration"
require_relative "oopsie/client"

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
      configuration.validate!
      client = Client.new(configuration)
      client.send_error(
        error_class: exception.class.name,
        message: exception.message,
        stack_trace: exception.backtrace&.join("\n")
      )
    rescue StandardError => e
      begin
        configuration.on_error&.call(e)
      rescue StandardError
        # Never crash the host app
      end
    end
  end
end

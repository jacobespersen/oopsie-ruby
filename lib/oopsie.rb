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
  end
end

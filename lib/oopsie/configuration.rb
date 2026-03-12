# frozen_string_literal: true

module Oopsie
  class ConfigurationError < StandardError; end

  class Configuration
    attr_accessor :api_key, :on_error, :ignored_exceptions
    attr_reader :endpoint

    def initialize
      @ignored_exceptions = []
    end

    def endpoint=(value)
      @endpoint = value&.chomp('/')
    end

    def validate!
      raise ConfigurationError, 'api_key is required' if api_key.nil? || api_key.empty?
      raise ConfigurationError, 'endpoint is required' if endpoint.nil? || endpoint.empty?
    end
  end
end

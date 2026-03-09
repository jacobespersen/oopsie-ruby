# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Oopsie
  class DeliveryError < StandardError; end

  class Client
    ERRORS_PATH = '/api/v1/errors'
    CONNECT_TIMEOUT = 5
    READ_TIMEOUT = 10

    def initialize(configuration)
      @configuration = configuration
    end

    def send_error(error_class:, message:, stack_trace:)
      uri = URI.join(@configuration.endpoint, ERRORS_PATH)
      request = build_request(uri, error_class:, message:, stack_trace:)
      response = execute(uri, request)
      handle_response(response)
    rescue StandardError => e
      notify_error(e)
    end

    private

    def build_request(uri, error_class:, message:, stack_trace:)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@configuration.api_key}"
      request.body = JSON.generate(
        error_class: error_class,
        message: message,
        stack_trace: stack_trace
      )
      request
    end

    def execute(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.request(request)
    end

    def handle_response(response)
      return if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, "Oopsie API returned #{response.code}: #{response.body}"
    end

    def notify_error(error)
      @configuration.on_error&.call(error)
    rescue StandardError
      # Never let callback errors escape
    end
  end
end

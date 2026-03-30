# frozen_string_literal: true

module Oopsie
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      context = begin
        Oopsie::ContextBuilder.from_rack_env(env)
      rescue StandardError => context_error
        Oopsie.safely_notify_error(context_error)
        nil
      end
      Oopsie.report(e, context: context)
      raise
    end
  end
end

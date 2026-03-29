# frozen_string_literal: true

module Oopsie
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      context = Oopsie::ContextBuilder.from_rack_env(env)
      Oopsie.report(e, context: context)
      raise
    end
  end
end

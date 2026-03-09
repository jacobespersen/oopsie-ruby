# frozen_string_literal: true

module Oopsie
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Oopsie.report(e)
      raise
    end
  end
end

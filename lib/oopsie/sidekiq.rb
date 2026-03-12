# frozen_string_literal: true

require 'oopsie'

module Oopsie
  module Sidekiq
    class ErrorHandler
      def call(exception, *)
        Oopsie.report(exception)
      end
    end
  end
end

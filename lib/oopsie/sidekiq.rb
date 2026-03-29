# frozen_string_literal: true

require 'oopsie'

module Oopsie
  module Sidekiq
    class ErrorHandler
      def call(exception, context = {}, *)
        ctx = begin
          job = context[:job] || context['job'] || {}
          Oopsie::ContextBuilder.from_sidekiq(job)
        rescue StandardError
          nil
        end
        Oopsie.report(exception, context: ctx)
      end
    end
  end
end

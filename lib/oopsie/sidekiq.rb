# frozen_string_literal: true

require 'oopsie'

module Oopsie
  module Sidekiq
    class ErrorHandler
      def call(exception, context = {}, *)
        job = context[:job] || context['job'] || {}
        ctx = Oopsie::ContextBuilder.from_sidekiq(job)
        Oopsie.report(exception, context: ctx)
      end
    end
  end
end

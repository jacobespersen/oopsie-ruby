# frozen_string_literal: true

module Oopsie
  # Walks Exception#cause and builds the exception_chain array for the Oopsie API.
  # Entries are ordered root-cause-first, outermost-last.
  module ExceptionChainBuilder
    MAX_CHAIN_LENGTH = 20  # Oopsie API limit
    MAX_FRAMES = 100       # Oopsie API limit per exception entry
    NOT_IN_APP_PATTERNS = ['/gems/', '/ruby/', '/vendor/', '<internal:'].freeze
    BACKTRACE_REGEX = /\A(.+):(\d+):in\s+[`'](.+)'\z/ # handles both pre-3.4 and 3.4+ formats

    module_function

    def build(exception)
      chain = unwind(exception)
      # Deduplicate by backtrace object identity — if the same backtrace array
      # is assigned to multiple exceptions (e.g., via set_backtrace), we avoid re-parsing it.
      parsed_backtrace_ids = {}.compare_by_identity

      chain.each_with_index.map do |ex, index|
        stacktrace = deduplicated_stacktrace(ex, parsed_backtrace_ids)
        build_entry(ex, outermost: index == chain.length - 1, stacktrace: stacktrace)
      end
    end

    def unwind(exception)
      chain = []
      current = exception
      seen = {}.compare_by_identity

      while current && chain.length < MAX_CHAIN_LENGTH
        break if seen.key?(current) # guard against circular causes

        seen[current] = true
        chain.unshift(current)
        current = current.cause
      end

      chain
    end

    def deduplicated_stacktrace(exception, parsed_backtrace_ids)
      bt = exception.backtrace
      return [] if bt.nil?
      return parsed_backtrace_ids[bt] if parsed_backtrace_ids.key?(bt)

      parsed_backtrace_ids[bt] = parse_backtrace(bt)
    end

    def build_entry(exception, outermost:, stacktrace:)
      mechanism_type = outermost ? 'generic' : 'chained'

      {
        type: exception.class.name,
        value: exception_message(exception),
        mechanism: { type: mechanism_type, handled: false },
        stacktrace: stacktrace
      }
    end

    # Prefers detailed_message (Ruby 3.2+) for richer context, ensures valid UTF-8.
    def exception_message(exception)
      msg = raw_message(exception)
      msg = msg.to_s unless msg.is_a?(String)
      encode_utf8(msg)
    rescue StandardError
      fallback_message(exception)
    end

    def raw_message(exception)
      if exception.respond_to?(:detailed_message)
        exception.detailed_message(highlight: false)
      else
        exception.message
      end
    end

    def fallback_message(exception)
      encode_utf8(exception.message.to_s)
    rescue StandardError
      '(failed to retrieve exception message)'
    end

    def encode_utf8(str)
      str.encode('UTF-8', invalid: :replace, undef: :replace, replace: "\uFFFD")
    end

    def parse_backtrace(backtrace)
      backtrace.first(MAX_FRAMES).map { |line| parse_frame(line) }
    end

    def parse_frame(line)
      match = BACKTRACE_REGEX.match(line)
      return { file: line, function: '', lineno: 0, in_app: in_app?(line) } unless match

      file = match[1]
      {
        file: file,
        function: match[3],
        lineno: match[2].to_i,
        in_app: in_app?(file)
      }
    end

    # Negative-match heuristic: anything under /gems/, /ruby/, /vendor/, or
    # <internal: is not in-app. Zero-config alternative to Sentry's positive-match
    # approach which requires knowing project_root.
    def in_app?(file)
      NOT_IN_APP_PATTERNS.none? { |pattern| file.include?(pattern) }
    end
  end
end

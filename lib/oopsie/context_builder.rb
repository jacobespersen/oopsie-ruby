# frozen_string_literal: true

module Oopsie
  # Builds execution_context hashes for the Oopsie API.
  # Only includes routing/metadata — never request bodies, sensitive headers
  # (auth, cookies), or job arguments (which may contain PII).
  module ContextBuilder
    DATA_KEYS = %i[job_class queue jid retry_count].freeze

    module_function

    def from_rack_env(env)
      method = env['REQUEST_METHOD'] || 'GET'
      path = env['PATH_INFO'] || '/'
      data = build_http_data(env, method, path)

      { type: 'http', description: "#{method} #{path}", data: data }
    end

    # Accepts both string and symbol keys (Sidekiq normalises to strings,
    # but callers may use symbols).
    def from_sidekiq(job_hash)
      values = resolve_sidekiq_values(job_hash)
      description = "#{values[:display_class] || values[:job_class] || 'Unknown'}#perform"
      data = DATA_KEYS.each_with_object({}) { |k, h| h[k] = values[k] unless values[k].nil? }

      { type: 'worker', description: description, data: data }
    end

    def default
      { type: 'unknown' }
    end

    def build_http_data(env, method, path)
      query = env['QUERY_STRING']
      url = query && !query.empty? ? "#{path}?#{query}" : path
      data = { method: method, url: url }
      data[:content_type] = env['CONTENT_TYPE'] if env['CONTENT_TYPE']
      data[:request_id] = env['HTTP_X_REQUEST_ID'] if env['HTTP_X_REQUEST_ID']
      data
    end

    def resolve_sidekiq_values(job_hash)
      {
        job_class: job_hash.key?('class') ? job_hash['class'] : job_hash[:class],
        display_class: job_hash.key?('display_class') ? job_hash['display_class'] : job_hash[:display_class],
        queue: job_hash.key?('queue') ? job_hash['queue'] : job_hash[:queue],
        jid: job_hash.key?('jid') ? job_hash['jid'] : job_hash[:jid],
        retry_count: job_hash.key?('retry_count') ? job_hash['retry_count'] : job_hash[:retry_count]
      }
    end
  end
end

# frozen_string_literal: true

RSpec.describe Oopsie::ContextBuilder do
  describe '.from_rack_env' do
    it 'builds HTTP context from a minimal Rack env' do
      env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/api/users' }

      result = described_class.from_rack_env(env)

      expect(result[:type]).to eq('http')
      expect(result[:description]).to eq('GET /api/users')
      expect(result[:data][:method]).to eq('GET')
      expect(result[:data][:url]).to eq('/api/users')
    end

    it 'excludes query string from url to avoid PII leakage' do
      env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/search', 'QUERY_STRING' => 'q=hello&token=secret' }

      result = described_class.from_rack_env(env)

      expect(result[:data][:url]).to eq('/search')
      expect(result[:description]).to eq('GET /search')
    end

    it 'includes content_type when present' do
      env = { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/api/users', 'CONTENT_TYPE' => 'application/json' }

      result = described_class.from_rack_env(env)

      expect(result[:data][:content_type]).to eq('application/json')
    end

    it 'includes request_id when X-Request-Id header is present' do
      env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/', 'HTTP_X_REQUEST_ID' => 'abc-123' }

      result = described_class.from_rack_env(env)

      expect(result[:data][:request_id]).to eq('abc-123')
    end

    it 'omits content_type and request_id when not present' do
      env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/' }

      result = described_class.from_rack_env(env)

      expect(result[:data]).not_to have_key(:content_type)
      expect(result[:data]).not_to have_key(:request_id)
    end

    it 'never includes QUERY_STRING in url' do
      env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/search', 'QUERY_STRING' => 'page=2' }

      result = described_class.from_rack_env(env)

      expect(result[:data][:url]).to eq('/search')
    end

    it 'handles empty env with defaults' do
      result = described_class.from_rack_env({})

      expect(result[:type]).to eq('http')
      expect(result[:description]).to eq('GET /')
      expect(result[:data][:method]).to eq('GET')
      expect(result[:data][:url]).to eq('/')
    end
  end

  describe '.from_sidekiq' do
    it 'builds worker context from a standard job hash' do
      job = { 'class' => 'UserMailer', 'queue' => 'mailers', 'jid' => 'abc123' }

      result = described_class.from_sidekiq(job)

      expect(result[:type]).to eq('worker')
      expect(result[:description]).to eq('UserMailer#perform')
      expect(result[:data][:job_class]).to eq('UserMailer')
      expect(result[:data][:queue]).to eq('mailers')
      expect(result[:data][:jid]).to eq('abc123')
    end

    it 'uses display_class when available' do
      job = { 'class' => 'Sidekiq::Extensions::DelayedMailer', 'display_class' => 'UserMailer' }

      result = described_class.from_sidekiq(job)

      expect(result[:description]).to eq('UserMailer#perform')
    end

    it 'includes retry_count when present' do
      job = { 'class' => 'HardWorker', 'retry_count' => 3 }

      result = described_class.from_sidekiq(job)

      expect(result[:data][:retry_count]).to eq(3)
    end

    it 'includes retry_count of 0' do
      job = { 'class' => 'HardWorker', 'retry_count' => 0 }

      result = described_class.from_sidekiq(job)

      expect(result[:data][:retry_count]).to eq(0)
    end

    it 'handles missing keys gracefully' do
      result = described_class.from_sidekiq({})

      expect(result[:type]).to eq('worker')
      expect(result[:description]).to eq('Unknown#perform')
      expect(result[:data]).to eq({})
    end

    it 'works with symbol keys' do
      job = { class: 'TestWorker', queue: 'default', jid: 'xyz' }

      result = described_class.from_sidekiq(job)

      expect(result[:data][:job_class]).to eq('TestWorker')
      expect(result[:description]).to eq('TestWorker#perform')
    end
  end

  describe '.default' do
    it 'returns unknown context' do
      expect(described_class.default).to eq({ type: 'unknown' })
    end
  end
end

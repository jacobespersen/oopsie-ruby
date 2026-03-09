# frozen_string_literal: true

RSpec.describe Oopsie::Configuration do
  describe '#api_key' do
    it 'defaults to nil' do
      config = described_class.new
      expect(config.api_key).to be_nil
    end

    it 'can be set' do
      config = described_class.new
      config.api_key = 'test-key'
      expect(config.api_key).to eq('test-key')
    end
  end

  describe '#endpoint' do
    it 'defaults to nil' do
      config = described_class.new
      expect(config.endpoint).to be_nil
    end

    it 'can be set' do
      config = described_class.new
      config.endpoint = 'https://oopsie.example.com'
      expect(config.endpoint).to eq('https://oopsie.example.com')
    end

    it 'strips trailing slash' do
      config = described_class.new
      config.endpoint = 'https://oopsie.example.com/'
      expect(config.endpoint).to eq('https://oopsie.example.com')
    end
  end

  describe '#on_error' do
    it 'defaults to nil' do
      config = described_class.new
      expect(config.on_error).to be_nil
    end

    it 'accepts a callable' do
      handler = ->(e) { e }
      config = described_class.new
      config.on_error = handler
      expect(config.on_error).to eq(handler)
    end
  end

  describe '#validate!' do
    it 'raises if api_key is missing' do
      config = described_class.new
      config.endpoint = 'https://oopsie.example.com'
      expect { config.validate! }.to raise_error(Oopsie::ConfigurationError, /api_key/)
    end

    it 'raises if endpoint is missing' do
      config = described_class.new
      config.api_key = 'test-key'
      expect { config.validate! }.to raise_error(Oopsie::ConfigurationError, /endpoint/)
    end

    it 'does not raise when both are set' do
      config = described_class.new
      config.api_key = 'test-key'
      config.endpoint = 'https://oopsie.example.com'
      expect { config.validate! }.not_to raise_error
    end
  end
end

RSpec.describe Oopsie do
  describe '.configure' do
    it 'yields a Configuration instance' do
      Oopsie.configure do |config|
        expect(config).to be_a(Oopsie::Configuration)
      end
    end

    it 'stores the configuration' do
      Oopsie.configure do |config|
        config.api_key = 'my-key'
        config.endpoint = 'https://example.com'
      end
      expect(Oopsie.configuration.api_key).to eq('my-key')
    end
  end

  describe '.reset_configuration!' do
    it 'clears the configuration' do
      Oopsie.configure do |config|
        config.api_key = 'my-key'
        config.endpoint = 'https://example.com'
      end
      Oopsie.reset_configuration!
      expect(Oopsie.configuration.api_key).to be_nil
    end
  end
end

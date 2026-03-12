# frozen_string_literal: true

require_relative 'lib/oopsie/version'

Gem::Specification.new do |spec|
  spec.name = 'oopsie-ruby'
  spec.version = Oopsie::VERSION
  spec.authors = ['Oopsie']
  spec.summary = 'Ruby client for Oopsie error reporting'
  spec.description = 'Lightweight Ruby gem that reports exceptions to an Oopsie instance. ' \
                     'Includes Rack middleware for automatic capture and a manual reporting API.'
  spec.homepage = 'https://github.com/jacobespersen/oopsie-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rack-test', '~> 2.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'actionpack', '~> 7.1'
  spec.add_development_dependency 'activesupport', '~> 7.1'
  spec.add_development_dependency 'railties', '~> 7.1'
  spec.metadata['rubygems_mfa_required'] = 'true'
end

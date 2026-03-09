# frozen_string_literal: true

require 'webmock/rspec'
require 'oopsie'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Reset Oopsie configuration between tests
  config.after(:each) do
    Oopsie.reset_configuration!
  end
end

WebMock.disable_net_connect!

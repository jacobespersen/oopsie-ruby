# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

oopsie-ruby is a lightweight Ruby gem that reports exceptions to an Oopsie instance. Zero runtime dependencies — uses Ruby stdlib (`net/http`, `json`, `uri`). Provides Rack middleware for automatic web error capture and `Oopsie.report(e)` for manual reporting. Silent failures with optional `on_error` callback.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake spec

# Run a single test file
bundle exec rspec spec/oopsie/some_spec.rb

# Run a single test by line number
bundle exec rspec spec/oopsie/some_spec.rb:42

# Lint
bundle exec rake rubocop

# Lint with auto-fix
bundle exec rubocop -A

# Run default tasks (spec + rubocop)
bundle exec rake
```

## Architecture

- `lib/oopsie.rb` — Main module: `Oopsie.configure`, `Oopsie.report(exception)`, `Oopsie.reset_configuration!`
- `lib/oopsie/configuration.rb` — `Configuration` class with `api_key`, `endpoint`, `on_error` callback, and `validate!`; `ConfigurationError` exception
- `lib/oopsie/client.rb` — `Client` class: POSTs to `/api/v1/errors` with Bearer auth; `DeliveryError` exception. Never raises — calls `on_error` callback on failure
- `lib/oopsie/middleware.rb` — Rack middleware: catches exceptions, reports via `Oopsie.report`, re-raises original error
- `lib/oopsie/version.rb` — Gem version constant

### Error reporting flow

`Oopsie.report(exception)` → validates config → `Client#send_error` POSTs `{error_class, message, stack_trace}` to `{endpoint}/api/v1/errors` with `Authorization: Bearer {api_key}`. On any failure (network, HTTP error, bad config), swallows the error and optionally calls `configuration.on_error.(e)`.

### Test structure

- `spec/spec_helper.rb` — WebMock disables network; `Oopsie.reset_configuration!` runs after each test
- `spec/oopsie/configuration_spec.rb` — Configuration defaults, validation, `Oopsie.configure` block
- `spec/oopsie/client_spec.rb` — HTTP request format, error handling, callback behavior
- `spec/oopsie_spec.rb` — `Oopsie.report` integration: exception serialization, config validation
- `spec/oopsie/middleware_spec.rb` — Rack middleware: reports errors, re-raises, passes through success

## Key Conventions

- Ruby >= 3.1 required; development on 3.4.8
- `frozen_string_literal: true` pragma on all Ruby files
- RuboCop with `NewCops: enable`; `Style/Documentation` is disabled
- WebMock is active in tests — all HTTP must be stubbed
- RSpec with `--format documentation`

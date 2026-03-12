# oopsie-ruby

Lightweight Ruby gem that reports exceptions to an [Oopsie](https://github.com/jacobespersen/oopsie) instance.

- Zero runtime dependencies (uses Ruby stdlib)
- Automatic error capture in Rails and Rack apps
- Sidekiq integration for background job errors
- Manual `Oopsie.report(e)` API
- Silent failures with optional `on_error` callback

## Installation

Add to your Gemfile:

```ruby
gem "oopsie-ruby"
```

Then run:

```bash
bundle install
```

## Configuration

```ruby
Oopsie.configure do |config|
  config.api_key = ENV["OOPSIE_API_KEY"]
  config.endpoint = "https://your-oopsie-instance.com"

  # Optional: exceptions to ignore (subclasses are also ignored)
  config.ignored_exceptions = [ActiveRecord::RecordNotFound, ActionController::RoutingError]

  # Optional: called when error reporting itself fails
  config.on_error = ->(e) { Rails.logger.warn("Oopsie error: #{e.message}") }
end
```

### Rails initializer

Create `config/initializers/oopsie.rb`:

```ruby
Oopsie.configure do |config|
  config.api_key = Rails.application.credentials.oopsie_api_key
  config.endpoint = "https://your-oopsie-instance.com"
end
```

## Rails

In Rails apps, the gem automatically:

- Inserts Rack middleware to capture unhandled exceptions
- Subscribes to `process_action.action_controller` notifications to capture errors handled by `rescue_from` in controllers and GraphQL schemas

No manual middleware setup needed — just add the gem and configure it.

## Rack Middleware

For non-Rails Rack apps, add the middleware manually:

```ruby
# config.ru
use Oopsie::Middleware
```

The middleware reports the error and re-raises it, so your existing error handling is unaffected.

## Sidekiq

To capture Sidekiq job errors, add the error handler in your Sidekiq server config:

```ruby
require "oopsie/sidekiq"

Sidekiq.configure_server do |config|
  config.error_handlers << Oopsie::Sidekiq::ErrorHandler.new
end
```

This reports on every job failure attempt, not just when retries are exhausted. Requires Sidekiq 7+.

## Manual Reporting

Report exceptions anywhere in your code:

```ruby
begin
  do_something_risky
rescue => e
  Oopsie.report(e)
end
```

`Oopsie.report` never raises — if reporting fails, it silently swallows the error (or calls your `on_error` callback).

## Requirements

- Ruby >= 3.1

## License

MIT

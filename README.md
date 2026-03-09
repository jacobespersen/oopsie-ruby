# oopsie-ruby

Lightweight Ruby gem that reports exceptions to an [Oopsie](https://github.com/jacobespersen/oopsie) instance.

- Zero runtime dependencies (uses Ruby stdlib)
- Rack middleware for automatic error capture
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

## Rack Middleware

Add the middleware to automatically capture unhandled exceptions:

```ruby
# config.ru
use Oopsie::Middleware
```

In Rails, add to `config/application.rb`:

```ruby
config.middleware.use Oopsie::Middleware
```

The middleware reports the error and re-raises it, so your existing error handling is unaffected.

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

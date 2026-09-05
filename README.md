# sms-sender

`sms-sender` is a Ruby gem for provider-neutral SMS delivery. It is designed
to let applications use one domain API while provider adapters handle the
details of individual HTTP APIs.

The project is being built as one gem with thin, lazily loaded provider
adapters. The planned runtime includes health-aware provider selection,
controlled failover, circuit breaking, capability filtering, and normalized
delivery results and errors.

## Status

Phases 1–6 are implemented through the TextBee, Semaphore, and Twilio adapters. The current release provides the message,
delivery, error, provider configuration, provider contract, supported-provider
catalog, lazy provider loading, and an injectable standard-library HTTP
transport, plus direct TextBee, Semaphore, and Twilio HTTP delivery. The high-level
delivery router and the remaining provider adapters are planned for subsequent
phases.

## Installation

Add the gem to your application's Gemfile:

```ruby
gem "sms-sender"
```

Then install it with Bundler:

```bash
bundle install
```

The gem currently has no mandatory provider SDK dependencies. Provider
integrations will use documented HTTP APIs directly.

## Current usage

The Phase 1 domain objects can be used to construct provider-neutral messages
and configurations:

```ruby
require "sms_sender"

message = Sms::Sender::Message.new(
  to: "+639171234567",
  body: "Your OTP is 123456",
  requirements: [:unicode]
)

configuration = Sms::Sender::ProviderConfiguration.new(
  name: :textbee,
  settings: {
    api_key: ENV.fetch("TEXTBEE_API_KEY")
  },
  priority: 10,
  capabilities: [:sms, :unicode]
)
```

`Message` and `ProviderConfiguration` are immutable after construction.
Recipients and bodies are validated, provider capabilities and message
requirements are normalized to symbols, and delivery results distinguish
provider acceptance from confirmed handset delivery.

Provider adapters implement the common contract:

```ruby
class MyProvider < Sms::Sender::Provider
  def deliver(message)
    # Translate `message` to the provider's HTTP API and return a
    # Sms::Sender::Delivery result.
  end
end
```

The high-level `Sms::Sender.deliver` API will be introduced with the routing
phases.

The registry exposes the providers supported by the gem without loading their
adapter implementations:

```ruby
Sms::Sender.providers
# => [:textbee, :semaphore, :twilio, :infobip]
```

Provider adapters can use the HTTP client without taking a dependency on a
provider SDK:

```ruby
client = Sms::Sender::HTTP::Client.new
response = client.request(
  :post,
  "https://example.test/messages",
  headers: { "Authorization" => "Bearer secret" },
  body: { to: message.to, body: message.body }
)
```

The client normalizes responses, serializes Hash bodies as JSON, supports
separate connection/read/write and total timeouts, maps transport failures to
normalized errors, and provides redacted headers for diagnostics.

The first provider adapter can be used through the registry:

```ruby
registry = Sms::Sender::ProviderRegistry.new
registry.configure(
  :textbee,
  settings: { api_key: ENV.fetch("TEXTBEE_API_KEY") }
)

delivery = registry.provider(:textbee).deliver(message)
```

TextBee sends through its default device unless `device_id` is configured.
The adapter returns an accepted delivery with the provider's batch ID; that
acceptance does not confirm handset delivery.

## Design principles

- One repository and one gem for all supported providers.
- Direct documented HTTP integrations instead of provider Ruby SDKs.
- Lazy loading so unused providers and dependencies remain unloaded.
- Thin adapters limited to configuration, authentication, HTTP mapping,
  response parsing, and provider error mapping.
- Provider-neutral routing, health, failover, and circuit-breaking behavior.
- Explicit error classification so terminal request errors do not trigger
  provider failover.
- Provider acceptance is distinct from final handset delivery.
- Process-local state initially, behind an abstraction for future shared state.

The initial provider set is TextBee, Semaphore, Twilio, and Infobip. Telnyx,
Vonage, and Plivo are potential later additions. AWS SNS is not part of the
initial provider set.

## Development

After checking out the repository, install dependencies:

```bash
bin/setup
```

Run the complete quality harness with:

```bash
bundle exec rake
```

This runs the test suite, RuboCop, RBS validation, and YARD documentation
coverage checks. Normal tests do not require provider credentials or send
real SMS messages.

Other useful commands:

```bash
bundle exec rake test       # Run tests
bundle exec rake rubocop   # Run RuboCop
bundle exec rake rbs       # Validate RBS signatures
bundle exec rake yard      # Generate API documentation
bundle exec rake build     # Build the gem
bin/console                # Open a Ruby console
```

## Roadmap

The implementation plan is organized as follows:

1. Core domain objects and contracts — complete
2. Provider registry and lazy loading — complete
3. Internal HTTP transport — complete
4. TextBee adapter — complete
5. Semaphore adapter — complete
6. Twilio adapter — complete; Infobip remains
7. Router, failure classification, and controlled failover
6. Circuit breaking, health tracking, and automatic election
7. Capability filtering, state storage, and observability
8. Additional providers and production hardening

## Contributing

Bug reports and pull requests are welcome at
[github.com/kanutocd/sms-sender](https://github.com/kanutocd/sms-sender).

Changes should preserve the provider-neutral core, keep adapters thin, and
include focused tests. Meaningful user, operator, integration, tooling, or
architectural changes should be recorded in `CHANGELOG.md` under `Unreleased`.

## License

This project is available under the [MIT License](LICENSE.txt).

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.

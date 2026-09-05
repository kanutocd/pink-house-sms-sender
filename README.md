# sms-sender

`sms-sender` is a Ruby gem for provider-neutral SMS delivery. It is designed
to let applications use one domain API while provider adapters handle the
details of individual HTTP APIs.

The project uses thin, lazily loaded provider adapters and a shared runtime
for health-aware provider selection, controlled failover, circuit breaking,
capability filtering, and normalized delivery results and errors.

## Origin

`sms-sender` was extracted from the Pink House SaaS project so its SMS
delivery capability could be reused independently of the application. Shared
delivery contracts and runtime behavior live in
[`sender-core`](https://github.com/kanutocd/sender-core); this gem owns SMS
validation, provider adapters, and SMS-specific request and response mapping.

## Installation

Add the gem to your application's Gemfile:

```ruby
gem "sms-sender"
```

Then install it with Bundler:

```bash
bundle install
```

The gem depends on the channel-neutral `sender-core` runtime and has no
mandatory provider SDK dependencies. Provider integrations use documented
HTTP APIs directly.

To configure providers from environment variables, list the desired providers
and identify the preferred default. The default receives the highest election
priority; other selected providers remain available for failover:

```bash
SMS_SENDER_PROVIDERS=textbee,twilio
SMS_SENDER_DEFAULT_PROVIDER=twilio
SMS_SENDER_TEXTBEE_SETTINGS='{"api_key":"...","device_id":"..."}'
```

Multiple accounts of one provider can be configured as named instances. An
instance name uses the adapter name as its prefix:

```bash
SMS_SENDER_PROVIDERS=textbee_primary,textbee_backup
SMS_SENDER_DEFAULT_PROVIDER=textbee_primary
SMS_SENDER_TEXTBEE_PRIMARY_SETTINGS='{"api_key":"...","device_id":"..."}'
SMS_SENDER_TEXTBEE_BACKUP_SETTINGS='{"api_key":"...","device_id":"..."}'
```

Each instance has independent priority, fallback, circuit-breaker, and health
state. Existing single-provider variables remain supported.

Call `Sms::Sender.configure_from_env` during application boot. Each provider's
`*_SETTINGS` value is a JSON object whose keys match that adapter's settings.
Provider metadata includes an advisory `support_level`; it is informational
only and does not prevent use of experimental, deprecated, or unsupported
providers.

## Compatibility boundary

Shared contracts such as `Message`, `Delivery`, `Provider`, `Router`, and
normalized errors are supplied by `sender-core` and exposed through the
existing `Sms::Sender` constants. SMS provider adapters and the SMS provider
catalog remain in this gem. Existing `lib/sms/sender/*` require paths are
preserved as compatibility shims.

## Usage

Construct provider-neutral messages and configurations:

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

The high-level API routes through configured providers and returns a normalized
delivery result:

```ruby
delivery = Sms::Sender.deliver(
  to: "+639171234567",
  body: "Your OTP is 123456"
)
```

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

### Compatibility and integration boundary

The supported runtime is Ruby 3.2 and newer. Standard CI uses only injected
HTTP transports and in-memory state; it never requires provider credentials,
network access, or live SMS delivery. Provider-specific integration tests are
opt-in and should be isolated from the normal `bundle exec rake` quality gate.

## Contributing

Bug reports and pull requests are welcome at
[github.com/kanutocd/sms-sender](https://github.com/kanutocd/sms-sender).

Changes should preserve the provider-neutral core, keep adapters thin, and
include focused tests. Meaningful user, operator, integration, tooling, or
architectural changes should be recorded in `CHANGELOG.md` under `Unreleased`.

## License

This project is available under the [MIT License](LICENSE.txt).

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.

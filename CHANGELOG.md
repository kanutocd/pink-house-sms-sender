## [Unreleased]

### Added

- Add the `Sms::Sender` API backed by shared `sender-core` contracts while
  preserving legacy require paths.
- Add provider configuration, lazy loading, capability filtering, and
  adapters for TextBee, Semaphore, Twilio, and Infobip.
- Add a standard-library HTTP transport with JSON and form serialization,
  configurable timeouts, normalized transport errors, and credential
  redaction.
- Add provider-neutral routing with deterministic election, bounded failover,
  circuit protection, health tracking, and attempt history.
- Add immutable delivery events and state updates for receipt integrations.
- Add dependency-free structured observability events for elections, attempts,
  failovers, and circuit transitions.

### Quality

- Add focused tests, concurrency coverage, RBS signatures, and the
  `bundle exec rake` quality harness with 100% YARD documentation coverage.
- Add gem metadata and publishing configuration.
- Add environment-based provider selection, default-provider priority, and
  JSON provider settings configuration.

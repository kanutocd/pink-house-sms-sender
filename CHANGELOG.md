## [Unreleased]

- Added the `bundle exec rake` quality harness covering tests, RuboCop, RBS,
  and YARD documentation coverage.
- Populated gem metadata and publishing configuration in `sms-sender.gemspec`.
- Added project guidance requiring meaningful changes to be recorded in the
  changelog.
- Added the Phase 1 provider-neutral core domain: messages, deliveries,
  normalized errors, provider configuration, and the provider contract.
- Replaced the generated README template with current installation, usage,
  architecture, development, and roadmap documentation.
- Added the provider registry with the initial provider catalog,
  explicit configuration, and lazy adapter loading.
- Added the injectable standard-library HTTP transport with response
  normalization, JSON serialization, timeout handling, transport error
  mapping, and credential redaction.
- Added the TextBee adapter with API-key authentication, request and response
  mapping, and normalized provider error handling.
- Added the Semaphore adapter with form-encoded request mapping,
  authentication, accepted-result handling, and normalized provider errors.
- Added the Twilio adapter with Basic authentication, form-encoded message
  submission, accepted-result handling, and normalized provider errors.
- Added the Infobip adapter with API-key authentication, advanced SMS JSON
  request mapping, accepted-result handling, and normalized provider errors.
- Added the basic provider router with enabled-provider filtering, priority
  ordering, and deterministic tie-breaking.
- Made retry and provider-failover classification explicit for normalized
  errors, distinguishing transient transport failures from terminal request
  and provider-configuration failures.
- Added bounded provider failover with deterministic ordering, terminal-error
  short-circuiting, and delivery attempt records.

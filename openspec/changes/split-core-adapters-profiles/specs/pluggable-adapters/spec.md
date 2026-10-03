## Purpose

Isoler identité, configuration et synchronisation derrière des interfaces stables pour que le core ne dépende d'aucun fournisseur.

## ADDED Requirements

### Requirement: Provider-independent core
The core SHALL depend only on the `IdentityProvider`, `ConfigSource` and `SyncTarget` interfaces and SHALL NOT import any concrete backend SDK.

#### Scenario: Core build without adapters
- **WHEN** the core is built and tested with only its default implementations
- **THEN** no Supabase, OIDC or HTTP backend dependency is required

#### Scenario: Contract tests
- **WHEN** an adapter is added
- **THEN** it passes the core contract suite, including idempotent retry and refusal of records attributed to another identity

### Requirement: Generic webhook synchronization
The system SHALL provide a sync target that sends each validated envelope over HTTPS with its UUID as idempotency key.

#### Scenario: Lost response
- **WHEN** a webhook accepts a record but the response is lost and the record is resent
- **THEN** the outbox keeps the record until acknowledged and the same UUID is reused

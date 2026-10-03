## Purpose

Associer chaque consultation à une identité et une organisation autorisées et empêcher les accès ou synchronisations entre organisations.

## ADDED Requirements

### Requirement: Organization isolation
The system SHALL require authenticated organization membership for remote access and enforce doctor/admin permissions on the server.

#### Scenario: Anonymous access
- **WHEN** an unauthenticated caller requests or inserts a consultation
- **THEN** access is denied

#### Scenario: Cross organization access
- **WHEN** a member of organization A reads or writes a record for B, including by forging identifiers
- **THEN** access is denied

#### Scenario: Role enforcement
- **WHEN** a doctor attempts an admin export or changes their own membership role
- **THEN** the operation is denied by the server

### Requirement: Attributed and repeatable synchronization
The system SHALL preserve record UUID, creator, organization, device and schema version across sync retries.

#### Scenario: Retry
- **WHEN** the same validated consultation is sent twice after a lost response
- **THEN** only one remote consultation exists and its attribution is unchanged

### Requirement: Account scoped offline data
The application SHALL allow previously configured local work offline while preventing data exposure across account changes.

#### Scenario: Expired session
- **WHEN** a known user's remote session expires offline
- **THEN** local work is retained and sync waits for successful reauthentication

#### Scenario: Account change
- **WHEN** the user signs out and another account signs in
- **THEN** the former account's records are hidden and its pending records are never sent under the new account

#### Scenario: Legacy records
- **WHEN** records lack organization attribution
- **THEN** they remain preserved and unsynchronized until explicitly assigned through the migration workflow

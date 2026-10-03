## Purpose

Permettre à un organisme d'utiliser la capture seule, sans compte ni serveur.

## ADDED Requirements

### Requirement: Standalone operation
The core SHALL capture, extract, validate, persist and export consultations without any identity provider, configuration server or network.

#### Scenario: No backend configured
- **WHEN** the app starts with the local identity, a bundled or imported package and no sync target
- **THEN** dictation or manual entry, human validation and history work offline and records persist across restarts

#### Scenario: Export
- **WHEN** a user exports validated records
- **THEN** a JSON or CSV file contains each record with UUID, schema id, schema version and payload, and no record is marked as synchronized

## Purpose

Permettre à plusieurs organisations de configurer Medipop sans modifier le moteur ni incorporer leurs données privées au projet public.

## ADDED Requirements

### Requirement: Versioned declarative packages
The application SHALL validate a versioned package before activation and use its supported fields for both review and extraction.

#### Scenario: Valid example
- **WHEN** the fictitious prescription example is loaded
- **THEN** dictation, editable review and validation preserve the existing prescription fields

#### Scenario: Invalid package
- **WHEN** a package is missing required metadata or uses an unsupported field type
- **THEN** activation fails visibly and the previous valid configuration remains active

### Requirement: Private companion independence
Medipop SHALL run its public example without the APTITUD directory, and SHALL preserve the schema identifier and version on saved records.

#### Scenario: Independent checkout
- **WHEN** only the Core and its public example are present
- **THEN** the example workflow is usable without APTITUD files

#### Scenario: Configuration update
- **WHEN** the active schema version changes
- **THEN** old records retain their original schema version and payload

## Purpose

Laisser chaque organisme choisir données, modèle, authentification, synchronisation et conformité sans modifier ni forker le core.

## ADDED Requirements

### Requirement: Declarative deployment profile
The application SHALL validate a profile selecting package, model, identity adapter, sync target and compliance options before activation, and SHALL contain no secrets.

#### Scenario: Valid profile
- **WHEN** a profile selects adapters registered in the app shell
- **THEN** the app starts with those adapters and options

#### Scenario: Invalid or unknown adapter
- **WHEN** a profile is malformed or names an adapter not registered in the shell
- **THEN** activation fails visibly and the last valid profile stays active

### Requirement: Private organization repositories
Organization-specific profiles, packages and branding SHALL live outside the public repositories.

#### Scenario: Public checkout
- **WHEN** only the public core and adapter repositories are present
- **THEN** example profiles run and no organization-specific data is included

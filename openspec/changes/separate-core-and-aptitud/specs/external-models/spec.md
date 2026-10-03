## Purpose

Installer et conserver un modèle local indépendamment des mises à jour du client tout en vérifiant son intégrité avant utilisation.

## ADDED Requirements

### Requirement: Verified external model installation
The application SHALL support local import or HTTPS download of a configured model, verify its expected SHA-256 before activation, and ship without a bundled GGUF.

#### Scenario: Fresh installation
- **WHEN** no valid model is installed
- **THEN** the app offers installation and explains that extraction is unavailable until completion

#### Scenario: Corruption or interruption
- **WHEN** download stops early or a downloaded/imported file has a different hash
- **THEN** the file is not activated and any previous valid model remains usable

#### Scenario: Offline use and app update
- **WHEN** a verified model already exists and the app is updated or starts without network
- **THEN** local inference uses it without a new download

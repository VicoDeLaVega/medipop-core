## Purpose

Fournir dans le core les garanties côté appareil nécessaires aux données de santé réelles, activables par profil selon la loi applicable.

## ADDED Requirements

### Requirement: On-device speech only
When `onDeviceSpeechOnly` is enabled, the core SHALL use only on-device speech recognition.

#### Scenario: On-device recognition unavailable
- **WHEN** the device or locale lacks on-device recognition
- **THEN** dictation is refused with an explanation and manual entry remains available

### Requirement: Encrypted local storage
When `encryptLocalDb` is enabled, local consultation databases SHALL be encrypted at rest with a key held in the platform secure store.

#### Scenario: Enabling encryption on an existing workspace
- **WHEN** encryption is enabled for a workspace with existing records
- **THEN** records are migrated to the encrypted database without loss and the outbox is preserved

### Requirement: Real-data pilot gate
Deployment documentation SHALL list hosting certified for the applicable jurisdiction (HDS in France), enabled device options, an impact assessment and a tested backup/restore as prerequisites before real patient data.

#### Scenario: Fictional-data pilot
- **WHEN** a pilot uses only fictional data
- **THEN** non-certified hosting may be used and the documentation states that no real or identifying data may be entered

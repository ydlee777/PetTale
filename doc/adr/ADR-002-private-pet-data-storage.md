# ADR-002: Private Pet Data Storage and Cloud Synchronization

- **Status:** Accepted
- **Date:** 2026-08-16
- **Decision Owners:** Pettale
- **Applies To:** Pettale V1

## Context

Pettale records a pet's long-term personal history, including diary entries, health-related events, weight, food, medication, behavior, activity, veterinary events, photos, and original voice-note transcripts.

This information is central to the user's relationship with Pettale and should be treated as private user data.

Users must also be able to change iPhones without losing their Pettale history.

At the same time, Pettale requires a lightweight service backend for account, subscription, trial, AI usage, and AI gateway functions.

Storing the complete pet diary in Pettale's own backend would increase privacy, security, infrastructure, retention, and operational responsibilities without being necessary for V1.

## Decision

The authoritative private pet history for Pettale V1 will be stored using:

- **SwiftData** for local structured persistence.
- **CloudKit / iCloud** for private synchronization and recovery across the user's Apple environment.

The Pettale service backend will **not** be the permanent source of truth for private pet diary/history data in V1.

Private pet data includes, unless explicitly decided otherwise:

- Pet profiles
- Diary entries
- Original transcripts
- Structured events
- Weight and other measurements
- Food records
- Health events
- Medication records
- Activity records
- Behavior records
- Sleep records
- Grooming records
- Veterinary events
- General life events
- Photos and attachment metadata

Voice audio is temporary by default.

After successful transcription, temporary audio should be deleted unless a separately approved feature explicitly requires retention.

## AI Processing Exception

AI operations require some user content to be processed outside the device.

Transcript text and compact structured context may therefore be transmitted through the Pettale backend to the configured AI provider when required to fulfill an explicit AI operation.

This processing does not change the storage boundary.

The backend should minimize retention of private pet content and must not silently evolve into a duplicate pet-history database.

## Rationale

This architecture:

- Keeps private pet history close to the user.
- Uses the Apple ecosystem for device synchronization.
- Reduces Pettale backend storage requirements.
- Reduces privacy/security exposure.
- Keeps the service backend lightweight.
- Allows a new iPhone to restore/synchronize history through the user's Apple environment.

## Consequences

### Positive

- Lower backend infrastructure/storage requirements.
- Smaller privacy and security attack surface.
- Natural fit for an iPhone-first application.
- User history can follow the user's Apple/iCloud environment.
- Clear separation between personal data and Pettale service-management data.

### Negative / Trade-offs

- CloudKit behavior and schema evolution must be designed carefully.
- Future Android synchronization will require a new cross-platform data strategy.
- Some future multi-user/family-sharing features may require revisiting the storage model.
- AI requests still require transient processing of selected user content outside the device.

## Implementation Rules

1. SwiftData is the local source of truth for structured pet history.
2. CloudKit/iCloud provides private synchronization where applicable.
3. Do not create backend pet-history tables merely for implementation convenience.
4. Do not persist full transcripts or diary history in PostgreSQL unless a later ADR explicitly authorizes it.
5. Keep temporary audio local and delete it after successful transcription by default.
6. Do not automatically send photos to an AI provider in V1.
7. Define migration/versioning rules before making incompatible SwiftData/CloudKit schema changes.
8. Collect and retain only service data necessary to operate Pettale.

## Future Android

This ADR intentionally optimizes V1 for iPhone.

If Android becomes an approved product, Pettale must explicitly decide how private history synchronizes across Apple and Android devices. That decision may supersede or amend this ADR.

Do not prematurely add a cross-platform pet-data backend solely for hypothetical Android support.

## Revisit When

Revisit this ADR if:

- Android development is approved.
- Cross-platform synchronization becomes a product requirement.
- Family/shared pet records are approved.
- CloudKit cannot satisfy a demonstrated production requirement.
- Regulatory, privacy, backup, or portability requirements materially change.

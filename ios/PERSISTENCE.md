# Oreamy private persistence

Current schema: `PettaleSchemaV4`, version `4.0.0`.

Published V1/V2/V3 schema definitions remain unchanged. V4 adds optional `PetRecord.diaryText` through a lightweight V3 → V4 migration. Existing records remain `nil`; migration never fabricates text or calls AI. A real disk-store test preserves the V3 Pet/photo/record/event graph, inserts a V4 diary record, and verifies it after reopen.

Published `PettaleSchemaV1` remains the immutable 1.0.0 schema containing only `Pet`. V2 retains the Pet fields and adds `PetRecord` and `PetEvent`. `PettaleMigrationPlan` performs a lightweight V1 → V2 migration because the change adds models and optional, inverse relationships without transforming existing Pet values. A real disk-store test creates a V1 Pet, reopens through the V2 migration plan, verifies all Pet fields and external photo data, and inserts a record/event afterward. Published schema types must remain unchanged.

The authoritative ownership chain is `Pet → PetRecord → PetEvent`; `PetEvent` does not duplicate a direct Pet relationship. CloudKit-compatible persisted relationships are optional, while public creation paths require their owner. Deleting a record cascades to its events. Deleting a Pet, an existing product behavior, now explicitly cascades its owned records and events so private history cannot become orphaned.

`PetRecord.originalTranscript` is the user-approved transcript, not the raw SpeechAnalyzer draft. `PetRecord.diaryText` is a separately reviewed natural retelling; new AI-assisted records normally contain both while the optional field preserves historical compatibility. `recordedAt` is the note's recording/context time. `PetEvent.occurredAt` represents the event time and defaults to its record's `recordedAt` when no more precise time is available. Event categories use 11 canonical language-independent codes. Optional `eventType` and `unit` codes are trimmed and uppercased; presentation labels are localized separately.

The application requests the private CloudKit database in `iCloud.com.oreamy.app`. Tests explicitly disable CloudKit and use isolated stores. Until an Apple Developer team enables and provisions the iCloud container, application container creation falls back to the same versioned schema in local-only storage.

Step 3E keeps AI output in transient `EditableEventDraft` values. An explicit Save validates and normalizes every draft, resolves the Pet by the recording session's fixed ID, then creates one `PetRecord` and zero or more `PetEvent` values in a single `ModelContext` transaction. A deliberately confirmed transcript-only record is supported when the user removes every event. Validation or persistence failure rolls the context back and leaves the review drafts available for retry. Successful Save clears temporary transcript, extraction, and audio session state.

`profilePhotoData` uses SwiftData external storage. This keeps larger binary values outside the primary database row while leaving storage and future private CloudKit synchronization under SwiftData. PhotosPicker imports are orientation-normalized through UIKit drawing, limited to a 1,024-pixel maximum dimension, and encoded as JPEG at 0.8 quality before persistence. The original full-resolution image is not retained.

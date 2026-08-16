# Pettale private persistence

Current schema: `PettaleSchemaV1`, version `1.0.0`.

V1 contains only `Pet`. `PettaleMigrationPlan` deliberately has no migration stages because there is no earlier schema. A future schema change should add a new `VersionedSchema` type, append it to the migration plan, and add only the required lightweight or custom stage. Published schema types must remain unchanged.

The application requests the private CloudKit database in `iCloud.com.pettale.app`. Tests explicitly disable CloudKit and use isolated stores. Until an Apple Developer team enables and provisions the iCloud container, application container creation falls back to the same versioned schema in local-only storage.

`profilePhotoData` uses SwiftData external storage. This keeps larger binary values outside the primary database row while leaving storage and future private CloudKit synchronization under SwiftData. PhotosPicker imports are orientation-normalized through UIKit drawing, limited to a 1,024-pixel maximum dimension, and encoded as JPEG at 0.8 quality before persistence. The original full-resolution image is not retained.

import SwiftData

enum PettaleMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [PettaleSchemaV1.self, PettaleSchemaV2.self, PettaleSchemaV3.self, PettaleSchemaV4.self]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: PettaleSchemaV1.self, toVersion: PettaleSchemaV2.self),
        .lightweight(fromVersion: PettaleSchemaV2.self, toVersion: PettaleSchemaV3.self),
        .lightweight(fromVersion: PettaleSchemaV3.self, toVersion: PettaleSchemaV4.self)
    ]
}

import SwiftData

enum PettaleMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [PettaleSchemaV1.self, PettaleSchemaV2.self]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: PettaleSchemaV1.self, toVersion: PettaleSchemaV2.self)
    ]
}

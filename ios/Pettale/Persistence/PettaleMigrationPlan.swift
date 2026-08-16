import SwiftData

enum PettaleMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [PettaleSchemaV1.self]
    static let stages: [MigrationStage] = []
}


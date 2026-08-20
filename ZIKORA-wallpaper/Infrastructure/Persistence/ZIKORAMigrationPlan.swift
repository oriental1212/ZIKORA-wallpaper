import SwiftData

enum ZIKORAMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ZIKORASchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

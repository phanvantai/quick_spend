import SwiftData

enum QuickSpendSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self]
    }
}

enum QuickSpendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [QuickSpendSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

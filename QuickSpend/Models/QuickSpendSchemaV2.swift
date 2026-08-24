import SwiftData

enum QuickSpendSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        QuickSpendSchemaV1.models + [BalanceAdjustment.self]
    }
}

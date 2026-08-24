import Foundation
import SwiftData

enum AppSchema {
    static let models = QuickSpendSchemaV1.models

    static let schema = Schema(versionedSchema: QuickSpendSchemaV1.self)
    static let migrationPlan: any SchemaMigrationPlan.Type = QuickSpendMigrationPlan.self

    static let cloudKitContainerId = "iCloud.com.randomtech.quickSpend"

    /// Builds the SwiftData container the app uses at runtime — CloudKit-synced
    /// when entitlements/network allow, local-only otherwise. App Intents reuse
    /// this so a Siri-triggered insert hits the same store the UI reads.
    static func makeModelContainer() throws -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerId)
        )
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: QuickSpendMigrationPlan.self,
            configurations: cloudConfig
        ) {
            return container
        }
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: QuickSpendMigrationPlan.self,
            configurations: localConfig
        )
    }
}

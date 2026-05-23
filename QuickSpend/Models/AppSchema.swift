import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Transaction.self,
        Category.self,
        RecurringTemplate.self,
        BalanceAnchor.self,
    ]

    static let schema = Schema(models)

    static let cloudKitContainerId = "iCloud.com.randomtech.quickSpend"

    /// Builds the SwiftData container the app uses at runtime — CloudKit-synced
    /// when entitlements/network allow, local-only otherwise. App Intents reuse
    /// this so a Siri-triggered insert hits the same store the UI reads.
    static func makeModelContainer() throws -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerId)
        )
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: localConfig)
    }
}

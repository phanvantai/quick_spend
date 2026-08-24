import Testing
import SwiftData
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("App Schema Migration Tests")
struct AppSchemaMigrationTests {
    @Test("App Store schema is frozen as V1")
    func appStoreSchemaIsV1() {
        #expect(QuickSpendSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(QuickSpendSchemaV1.models.count == 5)
        #expect(Set(AppSchema.schema.entities.map(\.name)) == [
            "Transaction", "Category", "RecurringTemplate", "BalanceAnchor", "Wallet"
        ])
        #expect(QuickSpendMigrationPlan.schemas.count == 1)
        #expect(QuickSpendMigrationPlan.stages.isEmpty)
    }

    @Test("Versioned V1 opens an existing unversioned App Store store in place")
    @MainActor
    func versionedV1OpensExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickSpendV1Migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("QuickSpend.sqlite")

        func createLegacyStore() throws {
            let legacySchema = Schema(QuickSpendSchemaV1.models)
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: ModelConfiguration(
                    "LegacyAppStore",
                    schema: legacySchema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
            )
            let legacyContext = legacyContainer.mainContext
            legacyContext.insert(Wallet.personal())
            legacyContext.insert(Transaction(
                id: "tx_preserved", amount: 125, note: "Preserve me",
                categoryId: "food", walletId: Wallet.personalID, type: .expense
            ))
            legacyContext.insert(RecurringTemplate(
                id: "recurring_preserved", amount: 500, note: "Rent",
                categoryId: "housing", walletId: Wallet.personalID, type: .expense
            ))
            legacyContext.insert(BalanceAnchor(
                walletId: Wallet.personalID, openingBalance: 2_000, anchorDate: .now
            ))
            legacyContext.insert(AppCategory(
                id: "food", name: "Food", iconName: "fork.knife",
                colorHex: "#FF9500", type: .expense, group: .dailyLiving, sortOrder: 0
            ))
            try legacyContext.save()
        }
        try createLegacyStore()

        let migratedContainer = try ModelContainer(
            for: AppSchema.schema,
            migrationPlan: QuickSpendMigrationPlan.self,
            configurations: ModelConfiguration(
                "VersionedV1",
                schema: AppSchema.schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        )
        let context = migratedContainer.mainContext
        #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.id == "tx_preserved")
        #expect(try context.fetch(FetchDescriptor<RecurringTemplate>()).first?.walletId == Wallet.personalID)
        #expect(try context.fetchCount(FetchDescriptor<AppCategory>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<BalanceAnchor>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Wallet>()) == 1)
    }
}

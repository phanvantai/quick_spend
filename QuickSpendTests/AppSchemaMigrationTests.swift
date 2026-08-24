import Testing
import SwiftData
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("App Schema Migration Tests")
struct AppSchemaMigrationTests {
    private func defaultSignature(for attribute: Schema.Attribute) -> String {
        guard let value = attribute.defaultValue else { return "nil" }
        // SwiftData boxes a literal `0` default as Int even when the declared
        // persisted value type is Double. Normalize through the schema type so
        // the signature describes the shipped property contract, not boxing.
        if attribute.valueType == Double.self, let number = value as? NSNumber {
            return "Double(\(number.doubleValue))"
        }
        switch value {
        case is Date:
            return "Date.dynamic"
        case let value as String:
            return "String(\(value))"
        case let value as Bool:
            return "Bool(\(value))"
        case let value as Int:
            return "Int(\(value))"
        case let value as Double:
            return "Double(\(value))"
        case let value as TransactionType:
            return "TransactionType(\(value.rawValue))"
        case let value as RecurrencePattern:
            return "RecurrencePattern(\(value.rawValue))"
        default:
            return String(reflecting: type(of: value))
        }
    }

    private func shippedV1Signature() -> [String] {
        Schema(versionedSchema: QuickSpendSchemaV1.self).entities.flatMap { entity in
            entity.properties.map { property in
                let kind = property.isAttribute ? "attribute" : "relationship"
                let optionality = property.isOptional ? "optional" : "required"
                let uniqueness = property.isUnique ? "unique" : "nonunique"
                let persistence = property.isTransient ? "transient" : "persisted"
                let defaultValue = (property as? Schema.Attribute)
                    .map(defaultSignature(for:)) ?? "n/a"
                return [
                    entity.name,
                    property.name,
                    String(describing: property.valueType),
                    kind,
                    optionality,
                    uniqueness,
                    persistence,
                    defaultValue
                ].joined(separator: "|")
            }
        }
        .sorted()
    }

    @Test("Runtime advances to V2 without changing the shipped V1 schema")
    func runtimeAdvancesToV2() {
        #expect(QuickSpendSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(QuickSpendSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(QuickSpendSchemaV1.models.count == 5)
        #expect(QuickSpendSchemaV2.models.count == 6)
        #expect(Set(AppSchema.schema.entities.map(\.name)) == [
            "Transaction", "Category", "RecurringTemplate", "BalanceAnchor", "Wallet",
            "BalanceAdjustment"
        ])
        #expect(QuickSpendMigrationPlan.schemas.count == 2)
        #expect(QuickSpendMigrationPlan.stages.count == 1)
    }

    @Test("V2 balance adjustment has the additive CloudKit-compatible signature")
    func balanceAdjustmentSignature() throws {
        let entity = try #require(AppSchema.schema.entities.first { $0.name == "BalanceAdjustment" })
        let signature = Set(entity.properties.map { property in
            let attribute = property as? Schema.Attribute
            return [
                entity.name,
                property.name,
                String(describing: property.valueType),
                property.isOptional ? "optional" : "required",
                property.isUnique ? "unique" : "nonunique",
                attribute.map(defaultSignature(for:)) ?? "n/a"
            ].joined(separator: "|")
        })
        #expect(signature == [
            "BalanceAdjustment|amount|Double|required|nonunique|Double(0.0)",
            "BalanceAdjustment|createdAt|Date|required|nonunique|Date.dynamic",
            "BalanceAdjustment|id|String|required|nonunique|String()",
            "BalanceAdjustment|operationId|String|required|nonunique|String()",
            "BalanceAdjustment|reason|String|required|nonunique|String(manual_reconciliation)",
            "BalanceAdjustment|sourceTransactionId|Optional<String>|optional|nonunique|nil",
            "BalanceAdjustment|walletId|String|required|nonunique|String(wallet_personal)"
        ])
    }

    @Test("V1 entity and property signature matches the shipped App Store schema")
    func v1PropertySignatureIsFrozen() {
        let expected = [
            "BalanceAnchor|anchorDate|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "BalanceAnchor|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "BalanceAnchor|id|String|attribute|required|nonunique|persisted|String(balance_anchor_wallet_personal)",
            "BalanceAnchor|openingBalance|Double|attribute|required|nonunique|persisted|Double(0.0)",
            "BalanceAnchor|walletId|String|attribute|required|nonunique|persisted|String(wallet_personal)",
            "Category|colorHex|String|attribute|required|nonunique|persisted|String(#000000)",
            "Category|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "Category|group|Optional<CategoryGroup>|attribute|optional|nonunique|persisted|nil",
            "Category|iconName|String|attribute|required|nonunique|persisted|String()",
            "Category|id|String|attribute|required|nonunique|persisted|String()",
            "Category|isHidden|Bool|attribute|required|nonunique|persisted|Bool(false)",
            "Category|name|String|attribute|required|nonunique|persisted|String()",
            "Category|sortOrder|Int|attribute|required|nonunique|persisted|Int(0)",
            "Category|type|TransactionType|attribute|required|nonunique|persisted|TransactionType(expense)",
            "Category|updatedAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "RecurringTemplate|amount|Double|attribute|required|nonunique|persisted|Double(0.0)",
            "RecurringTemplate|categoryId|String|attribute|required|nonunique|persisted|String()",
            "RecurringTemplate|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "RecurringTemplate|endDate|Optional<Date>|attribute|optional|nonunique|persisted|nil",
            "RecurringTemplate|id|String|attribute|required|nonunique|persisted|String()",
            "RecurringTemplate|isActive|Bool|attribute|required|nonunique|persisted|Bool(true)",
            "RecurringTemplate|lastGeneratedDate|Optional<Date>|attribute|optional|nonunique|persisted|nil",
            "RecurringTemplate|note|String|attribute|required|nonunique|persisted|String()",
            "RecurringTemplate|pattern|RecurrencePattern|attribute|required|nonunique|persisted|RecurrencePattern(monthly)",
            "RecurringTemplate|startDate|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "RecurringTemplate|type|TransactionType|attribute|required|nonunique|persisted|TransactionType(expense)",
            "RecurringTemplate|updatedAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "RecurringTemplate|walletId|String|attribute|required|nonunique|persisted|String(wallet_personal)",
            "Transaction|amount|Double|attribute|required|nonunique|persisted|Double(0.0)",
            "Transaction|categoryId|String|attribute|required|nonunique|persisted|String()",
            "Transaction|confidence|Optional<Double>|attribute|optional|nonunique|persisted|nil",
            "Transaction|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "Transaction|date|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "Transaction|id|String|attribute|required|nonunique|persisted|String()",
            "Transaction|note|String|attribute|required|nonunique|persisted|String()",
            "Transaction|rawInput|Optional<String>|attribute|optional|nonunique|persisted|nil",
            "Transaction|type|TransactionType|attribute|required|nonunique|persisted|TransactionType(expense)",
            "Transaction|updatedAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "Transaction|walletId|String|attribute|required|nonunique|persisted|String(wallet_personal)",
            "Wallet|colorHex|String|attribute|required|nonunique|persisted|String(#000000)",
            "Wallet|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
            "Wallet|iconName|String|attribute|required|nonunique|persisted|String()",
            "Wallet|id|String|attribute|required|nonunique|persisted|String()",
            "Wallet|isArchived|Bool|attribute|required|nonunique|persisted|Bool(false)",
            "Wallet|name|String|attribute|required|nonunique|persisted|String()",
            "Wallet|sortOrder|Int|attribute|required|nonunique|persisted|Int(0)",
            "Wallet|updatedAt|Date|attribute|required|nonunique|persisted|Date.dynamic"
        ]

        #expect(shippedV1Signature() == expected)
    }

    @Test("V2 opens an existing unversioned App Store store in place")
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
        context.insert(BalanceAdjustment(
            id: "migration_adjustment", operationId: "migration",
            walletId: Wallet.personalID, amount: 75, reason: .manualReconciliation
        ))
        try context.save()

        let adjustments = try context.fetch(FetchDescriptor<BalanceAdjustment>())
        #expect(adjustments.count == 1)
        #expect(adjustments.first?.amount == 75)
    }
}

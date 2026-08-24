import Testing
import Foundation
import SwiftData
@testable import QuickSpend

@Suite("WalletService Tests")
@MainActor
struct WalletServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
            configurations: config
        )
    }

    private func makePreferences() -> PreferencesService {
        let suiteName = "wallet.service.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PreferencesService(defaults: defaults)
    }

    @Test("bootstrap creates only Personal wallet for a new install")
    func bootstrapCreatesOnlyPersonalWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()

        let result = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        #expect(result.didCreatePersonalWallet == true)
        #expect(result.didMigrateLegacyData == false)
        #expect(wallets.count == 1)
        #expect(wallets.first?.id == Wallet.personalID)
        #expect(wallets.first?.name == "Personal")
        #expect(preferences.defaultWalletId == Wallet.personalID)
        #expect(preferences.selectedWalletScopeRawValue == WalletScope.wallet(Wallet.personalID).rawValue)
    }

    @Test("bootstrap assigns legacy data to Personal wallet")
    func bootstrapAssignsLegacyDataToPersonalWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)

        let transaction = Transaction(amount: 25, note: "Legacy", categoryId: "food", type: .expense)
        transaction.walletId = ""
        let template = RecurringTemplate(amount: 100, note: "Legacy recurring", categoryId: "salary", type: .income)
        template.walletId = ""
        let anchor = BalanceAnchor(openingBalance: 500, anchorDate: anchorDate)
        anchor.walletId = ""

        context.insert(transaction)
        context.insert(template)
        context.insert(anchor)
        try context.save()

        let result = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        #expect(result.didMigrateLegacyData == true)
        #expect(transaction.walletId == Wallet.personalID)
        #expect(template.walletId == Wallet.personalID)
        #expect(anchor.walletId == Wallet.personalID)
        #expect(preferences.shouldShowWalletsWhatsNew == true)
    }

    @Test("bootstrap is idempotent and does not overwrite assigned wallets")
    func bootstrapIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()

        let custom = Wallet(id: "wallet_side_work", name: "Side Work", iconName: "briefcase.fill", colorHex: "#2563EB")
        let transaction = Transaction(amount: 75, note: "Already assigned", categoryId: "tools", walletId: custom.id, type: .expense)
        context.insert(custom)
        context.insert(transaction)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)
        let second = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        #expect(second.didCreatePersonalWallet == false)
        #expect(wallets.filter { $0.id == Wallet.personalID }.count == 1)
        #expect(transaction.walletId == custom.id)
    }

    @Test("bootstrap assigns an empty recurring wallet to the active configured default")
    func bootstrapAssignsEmptyRecurringWalletToDefault() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let personal = Wallet.personal()
        let sideWork = Wallet(
            id: "wallet_side_work", name: "Side Work",
            iconName: "briefcase.fill", colorHex: "#2563EB"
        )
        let template = RecurringTemplate(amount: 500, note: "Tools", categoryId: "tools")
        template.walletId = ""
        context.insert(personal)
        context.insert(sideWork)
        context.insert(template)
        preferences.setDefaultWalletId(sideWork.id)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        #expect(template.walletId == "wallet_side_work")
    }

    @Test("bootstrap repairs missing and archived recurring wallets")
    func bootstrapRepairsInvalidRecurringWallets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let personal = Wallet.personal()
        let archived = Wallet(
            id: "wallet_archived", name: "Archived", iconName: "archivebox.fill",
            colorHex: "#8E8E93", isArchived: true
        )
        let archivedTemplate = RecurringTemplate(
            amount: 100, note: "Archived wallet", categoryId: "other_expense",
            walletId: "wallet_archived"
        )
        let missingTemplate = RecurringTemplate(
            amount: 200, note: "Missing wallet", categoryId: "other_expense",
            walletId: "wallet_missing"
        )
        context.insert(personal)
        context.insert(archived)
        context.insert(archivedTemplate)
        context.insert(missingTemplate)
        preferences.setDefaultWalletId(archived.id)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        #expect(archivedTemplate.walletId == "wallet_personal")
        #expect(missingTemplate.walletId == "wallet_personal")
    }

    @Test("bootstrap keeps a valid recurring wallet and is idempotent")
    func bootstrapKeepsValidRecurringWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let personal = Wallet.personal()
        let sideWork = Wallet(
            id: "wallet_side_work", name: "Side Work",
            iconName: "briefcase.fill", colorHex: "#2563EB"
        )
        let template = RecurringTemplate(
            amount: 500, note: "Tools", categoryId: "tools",
            walletId: "wallet_side_work"
        )
        context.insert(personal)
        context.insert(sideWork)
        context.insert(template)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)
        let second = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        #expect(template.walletId == "wallet_side_work")
        #expect(second.didCreatePersonalWallet == false)
        #expect(second.didMigrateLegacyData == false)
    }

    @Test("bootstrap removes a Personal wallet duplicated by a later CloudKit import")
    func bootstrapRemovesImportedPersonalWalletDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let importedCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let importedUpdatedAt = importedCreatedAt.addingTimeInterval(60)
        let localSeedDate = importedCreatedAt.addingTimeInterval(120)

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)
        let original = try #require(context.fetch(FetchDescriptor<Wallet>()).first)
        original.createdAt = localSeedDate
        original.updatedAt = localSeedDate

        let imported = Wallet(
            id: Wallet.personalID,
            name: "My Personal Wallet",
            iconName: "star.fill",
            colorHex: "#FF9500",
            createdAt: importedCreatedAt,
            updatedAt: importedUpdatedAt
        )
        let transaction = Transaction(
            id: "tx_duplicate_reference",
            amount: 125,
            note: "Must survive wallet de-duplication",
            categoryId: "food",
            walletId: Wallet.personalID,
            type: .expense
        )
        context.insert(imported)
        context.insert(transaction)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        let personalWallets = try context.fetch(FetchDescriptor<Wallet>())
            .filter { $0.id == Wallet.personalID }
        #expect(personalWallets.count == 1)
        #expect(personalWallets.first?.name == "My Personal Wallet")
        #expect(personalWallets.first?.iconName == "star.fill")
        #expect(personalWallets.first?.colorHex == "#FF9500")
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count == 1)
        #expect(transactions.first?.id == "tx_duplicate_reference")
        #expect(transactions.first?.walletId == Wallet.personalID)
        #expect(transactions.first?.amount == 125)
    }

    @Test("bootstrap keeps the latest edited wallet among duplicate IDs")
    func bootstrapKeepsLatestEditedDuplicateWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let earlierEdited = Wallet(
            id: "wallet_duplicate", name: "Earlier edited", iconName: "1.circle.fill",
            colorHex: "#2563EB", createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(60)
        )
        let latestEdited = Wallet(
            id: "wallet_duplicate", name: "Latest edited", iconName: "2.circle.fill",
            colorHex: "#FF9500", createdAt: createdAt.addingTimeInterval(10),
            updatedAt: createdAt.addingTimeInterval(120)
        )
        context.insert(earlierEdited)
        context.insert(latestEdited)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        let survivingWallets = try context.fetch(FetchDescriptor<Wallet>())
            .filter { $0.id == "wallet_duplicate" }
        #expect(survivingWallets.count == 1)
        #expect(survivingWallets.first?.name == "Latest edited")
    }

    @Test("bootstrap keeps the earliest unedited wallet among duplicate IDs")
    func bootstrapKeepsEarliestUneditedDuplicateWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let earliestUnedited = Wallet(
            id: "wallet_duplicate", name: "Earliest created", iconName: "1.circle.fill",
            colorHex: "#2563EB", createdAt: createdAt, updatedAt: createdAt
        )
        let laterUnedited = Wallet(
            id: "wallet_duplicate", name: "Later created", iconName: "2.circle.fill",
            colorHex: "#FF9500", createdAt: createdAt.addingTimeInterval(60),
            updatedAt: createdAt.addingTimeInterval(60)
        )
        context.insert(earliestUnedited)
        context.insert(laterUnedited)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        let survivingWallets = try context.fetch(FetchDescriptor<Wallet>())
            .filter { $0.id == "wallet_duplicate" }
        #expect(survivingWallets.count == 1)
        #expect(survivingWallets.first?.name == "Earliest created")
    }

    @Test("bootstrap converts legacy personal balance anchor to wallet-scoped anchor ID")
    func bootstrapConvertsLegacyAnchorId() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let preferences = makePreferences()
        let anchor = BalanceAnchor(
            id: BalanceAnchor.legacySingletonID,
            walletId: "",
            openingBalance: 100,
            anchorDate: Date()
        )
        context.insert(anchor)
        try context.save()

        _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

        #expect(anchor.walletId == Wallet.personalID)
        #expect(anchor.id == BalanceAnchor.id(for: Wallet.personalID))
    }

    @Test("wallet IDs for all scope include archived wallets so historical transactions remain visible")
    func allScopeIncludesArchivedWalletIds() {
        let activePersonal = Wallet.personal()
        let archivedSideWork = Wallet(
            id: "wallet_side_work",
            name: "Side Work",
            iconName: "briefcase.fill",
            colorHex: "#2563EB",
            isArchived: true
        )

        let ids = WalletService.walletIdsForAllScope(wallets: [activePersonal, archivedSideWork])

        #expect(ids == [Wallet.personalID, "wallet_side_work"])
    }

    @Test("resolving default wallet falls back to Personal when the stored default is archived")
    func defaultWalletFallsBackWhenArchived() {
        let preferences = makePreferences()
        preferences.setDefaultWalletId("wallet_side_work")
        let personal = Wallet.personal()
        let archivedSideWork = Wallet(
            id: "wallet_side_work",
            name: "Side Work",
            iconName: "briefcase.fill",
            colorHex: "#2563EB",
            isArchived: true
        )

        let resolved = WalletService.resolvedDefaultWalletId(
            wallets: [personal, archivedSideWork],
            preferences: preferences
        )

        #expect(resolved == Wallet.personalID)
    }

    @Test("resolving default wallet uses the stored default when it is active")
    func defaultWalletUsesStoredActiveWallet() {
        let preferences = makePreferences()
        preferences.setDefaultWalletId("wallet_side_work")
        let personal = Wallet.personal()
        let sideWork = Wallet(
            id: "wallet_side_work",
            name: "Side Work",
            iconName: "briefcase.fill",
            colorHex: "#2563EB"
        )

        let resolved = WalletService.resolvedDefaultWalletId(
            wallets: [personal, sideWork],
            preferences: preferences
        )

        #expect(resolved == "wallet_side_work")
    }
}

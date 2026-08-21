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

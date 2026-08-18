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
}

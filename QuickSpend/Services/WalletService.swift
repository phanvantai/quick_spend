import Foundation
import SwiftData

struct WalletBootstrapResult {
    let didCreatePersonalWallet: Bool
    let didMigrateLegacyData: Bool
}

@MainActor
enum WalletService {
    static func bootstrapIfNeeded(modelContext: ModelContext) throws -> WalletBootstrapResult {
        try bootstrapIfNeeded(modelContext: modelContext, preferences: .shared)
    }

    static func bootstrapIfNeeded(
        modelContext: ModelContext,
        preferences: PreferencesService
    ) throws -> WalletBootstrapResult {
        var didCreatePersonalWallet = false
        var didMigrateLegacyData = false

        let wallets = try modelContext.fetch(FetchDescriptor<Wallet>())
        if !wallets.contains(where: { $0.id == Wallet.personalID }) {
            modelContext.insert(Wallet.personal())
            didCreatePersonalWallet = true
        }

        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        for transaction in transactions where transaction.walletId.isEmpty {
            transaction.walletId = Wallet.personalID
            didMigrateLegacyData = true
        }

        let templates = try modelContext.fetch(FetchDescriptor<RecurringTemplate>())
        for template in templates where template.walletId.isEmpty {
            template.walletId = Wallet.personalID
            didMigrateLegacyData = true
        }

        let anchors = try modelContext.fetch(FetchDescriptor<BalanceAnchor>())
        for anchor in anchors where anchor.walletId.isEmpty {
            anchor.walletId = Wallet.personalID
            didMigrateLegacyData = true
        }

        if preferences.defaultWalletId.isEmpty {
            preferences.setDefaultWalletId(Wallet.personalID)
        }
        if WalletScope(rawValue: preferences.selectedWalletScopeRawValue) == nil {
            preferences.setSelectedWalletScope(.wallet(Wallet.personalID))
        }
        if didMigrateLegacyData {
            preferences.setShouldShowWalletsWhatsNew(true)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return WalletBootstrapResult(
            didCreatePersonalWallet: didCreatePersonalWallet,
            didMigrateLegacyData: didMigrateLegacyData
        )
    }
}

import Foundation
import SwiftData

struct WalletBootstrapResult {
    let didCreatePersonalWallet: Bool
    let didMigrateLegacyData: Bool
}

@MainActor
enum WalletService {
    static func activeWallets(from wallets: [Wallet]) -> [Wallet] {
        wallets
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func walletIdsForAllScope(wallets: [Wallet]) -> [String] {
        let sortedWallets = wallets.sorted { $0.sortOrder < $1.sortOrder }
        let ids = sortedWallets.map(\.id)
        return ids.isEmpty ? [Wallet.personalID] : ids
    }

    static func resolvedDefaultWalletId(wallets: [Wallet]) -> String {
        resolvedDefaultWalletId(wallets: wallets, preferences: .shared)
    }

    static func resolvedDefaultWalletId(
        wallets: [Wallet],
        preferences: PreferencesService
    ) -> String {
        let activeWallets = activeWallets(from: wallets)
        if activeWallets.contains(where: { $0.id == preferences.defaultWalletId }) {
            return preferences.defaultWalletId
        }
        if activeWallets.contains(where: { $0.id == Wallet.personalID }) {
            return Wallet.personalID
        }
        return activeWallets.first?.id ?? Wallet.personalID
    }

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
        let groupedWallets = Dictionary(grouping: wallets, by: \Wallet.id)
        var canonicalWallets: [Wallet] = []
        for walletGroup in groupedWallets.values {
            let canonical = walletGroup.sorted { lhs, rhs in
                let lhsWasEdited = lhs.updatedAt > lhs.createdAt
                let rhsWasEdited = rhs.updatedAt > rhs.createdAt
                if lhsWasEdited != rhsWasEdited {
                    return lhsWasEdited
                }
                if lhsWasEdited, lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.createdAt < rhs.createdAt
            }[0]
            canonicalWallets.append(canonical)
            for duplicate in walletGroup where duplicate !== canonical {
                modelContext.delete(duplicate)
            }
        }

        if !canonicalWallets.contains(where: { $0.id == Wallet.personalID }) {
            let personalWallet = Wallet.personal()
            modelContext.insert(personalWallet)
            canonicalWallets.append(personalWallet)
            didCreatePersonalWallet = true
        }

        let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        for transaction in transactions where transaction.walletId.isEmpty {
            transaction.walletId = Wallet.personalID
            didMigrateLegacyData = true
        }

        let templates = try modelContext.fetch(FetchDescriptor<RecurringTemplate>())
        let activeCanonicalWallets = activeWallets(from: canonicalWallets)
        let resolvedDefaultWalletId = resolvedDefaultWalletId(
            wallets: activeCanonicalWallets,
            preferences: preferences
        )
        let activeWalletIds = Set(activeCanonicalWallets.map(\.id))
        for template in templates
        where template.walletId.isEmpty || !activeWalletIds.contains(template.walletId) {
            template.walletId = resolvedDefaultWalletId
            didMigrateLegacyData = true
        }

        let anchors = try modelContext.fetch(FetchDescriptor<BalanceAnchor>())
        for anchor in anchors {
            if anchor.walletId.isEmpty {
                anchor.walletId = Wallet.personalID
                didMigrateLegacyData = true
            }
            let expectedId = BalanceAnchor.id(for: anchor.walletId)
            if anchor.id == BalanceAnchor.legacySingletonID || anchor.id.isEmpty {
                anchor.id = expectedId
                didMigrateLegacyData = true
            }
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

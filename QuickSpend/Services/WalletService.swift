import Foundation
import SwiftData

struct WalletBootstrapResult {
    let didCreatePersonalWallet: Bool
    let didMigrateLegacyData: Bool
}

@MainActor
enum WalletService {
    /// Old App Store builds evaluated `createdAt` and `updatedAt` defaults
    /// independently. The resulting sub-second delta is constructor jitter, not
    /// evidence that the user edited a wallet.
    private static let editTimestampTolerance: TimeInterval = 1

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

    static func canonicalWallet(from wallets: [Wallet]) -> Wallet {
        precondition(!wallets.isEmpty, "A canonical wallet requires at least one candidate")
        return wallets.dropFirst().reduce(wallets[0]) { canonical, candidate in
            isPreferredCanonical(candidate, over: canonical) ? candidate : canonical
        }
    }

    private static func isPreferredCanonical(_ lhs: Wallet, over rhs: Wallet) -> Bool {
        let lhsWasEdited = wasMeaningfullyEdited(lhs)
        let rhsWasEdited = wasMeaningfullyEdited(rhs)
        if lhsWasEdited != rhsWasEdited {
            return lhsWasEdited
        }
        if lhsWasEdited, lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        // V1 has no immutable per-row business key beyond `id`. Compare every
        // remaining persisted content field so equal timestamp ties resolve the
        // same way regardless of fetch order. Exact duplicates are semantically
        // indistinguishable, so either row is an equivalent survivor.
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        if lhs.iconName != rhs.iconName { return lhs.iconName < rhs.iconName }
        if lhs.colorHex != rhs.colorHex { return lhs.colorHex < rhs.colorHex }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        if lhs.isArchived != rhs.isArchived { return !lhs.isArchived }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id < rhs.id
    }

    private static func wasMeaningfullyEdited(_ wallet: Wallet) -> Bool {
        let timestampIndicatesEdit = wallet.updatedAt.timeIntervalSince(wallet.createdAt)
            > editTimestampTolerance
        return timestampIndicatesEdit || hasCustomizedPersonalMetadata(wallet)
    }

    private static func hasCustomizedPersonalMetadata(_ wallet: Wallet) -> Bool {
        guard wallet.id == Wallet.personalID else { return false }
        return wallet.name != "Personal"
            || wallet.iconName != "person.crop.circle.fill"
            || wallet.colorHex != "#2563EB"
            || wallet.sortOrder != 0
            || wallet.isArchived
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
            let canonical = canonicalWallet(from: walletGroup)
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

        let adjustments = try modelContext.fetch(FetchDescriptor<BalanceAdjustment>())
        let groupedAdjustments = Dictionary(grouping: adjustments, by: \BalanceAdjustment.id)
        for group in groupedAdjustments.values where group.count > 1 {
            let ordered = group.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                if lhs.operationId != rhs.operationId { return lhs.operationId < rhs.operationId }
                if lhs.walletId != rhs.walletId { return lhs.walletId < rhs.walletId }
                if lhs.amount != rhs.amount { return lhs.amount < rhs.amount }
                if lhs.reason != rhs.reason { return lhs.reason < rhs.reason }
                return (lhs.sourceTransactionId ?? "") < (rhs.sourceTransactionId ?? "")
            }
            for duplicate in ordered.dropFirst() {
                modelContext.delete(duplicate)
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

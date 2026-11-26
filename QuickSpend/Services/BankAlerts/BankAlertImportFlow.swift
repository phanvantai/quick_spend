import Foundation
import SwiftData

enum BankAlertImportResult: Equatable {
    case saved(Transaction)
    /// Added to the review list (generic parse, or the user reviews everything).
    case queued(PendingBankAlert)
    /// This money movement was already recorded or queued (it can arrive as a
    /// notification, an SMS and an email).
    case duplicate
    /// Not a balance alert: OTP, promotion, failed transfer, empty text.
    case unrecognized
    /// The app currency is not VND, so the alert's amount can't be stored as-is.
    case unsupportedCurrency
    /// The user paused bank alerts in Settings.
    case disabled
}

/// What the import needs from the user's settings, passed in so tests don't
/// touch the real preferences.
struct BankAlertSettings {
    var isEnabled = true
    var alwaysReview = false
    var currency = "VND"
    var defaultWalletId = Wallet.personalID
    /// `BankInfo.id` → wallet id.
    var walletIds: [String: String] = [:]
    /// Wallets that can receive transactions; a mapping to any other is ignored.
    var activeWalletIds: Set<String>? = nil
    /// Formats the user taught with "Learn from a sample".
    var templates: [BankAlertTemplate] = []

    func walletId(for bank: BankInfo?) -> String {
        guard let bank, let mapped = walletIds[bank.id] else { return defaultWalletId }
        if let active = activeWalletIds, !active.contains(mapped) { return defaultWalletId }
        return mapped
    }

    @MainActor
    static func current(
        preferences: PreferencesService = .shared,
        templates: BankAlertTemplateStore = .shared,
        wallets: [Wallet]
    ) -> BankAlertSettings {
        BankAlertSettings(
            isEnabled: preferences.bankAlertsEnabled,
            alwaysReview: preferences.bankAlertsAlwaysReview,
            currency: preferences.getConfig().currency,
            defaultWalletId: WalletService.resolvedDefaultWalletId(wallets: wallets, preferences: preferences),
            walletIds: preferences.bankAlertWalletIds,
            activeWalletIds: Set(WalletService.activeWallets(from: wallets).map(\.id)),
            templates: templates.templates
        )
    }
}

/// Turns a bank alert's text into a saved transaction or a review item, with
/// no network and no AI parse. Used by `AddBankAlertIntent` and the review
/// screen; kept free of App Intents and UI so it can be unit-tested.
@MainActor
enum BankAlertImportFlow {

    static let idPrefix = "bankalert:"
    /// Two alerts with the same signed amount this close together are taken
    /// to be the same money movement seen through two channels.
    static let duplicateWindow: TimeInterval = 120

    static func importAlert(
        text: String,
        bankHint: BankInfo? = nil,
        settings: BankAlertSettings,
        in context: ModelContext,
        inbox: BankAlertInbox,
        categorizer: BankAlertCategorizer? = nil,
        balanceService: BalanceService? = nil,
        now: Date = .now
    ) async throws -> BankAlertImportResult {
        guard settings.isEnabled else { return .disabled }
        guard let alert = BankAlertParser.parse(text, bankHint: bankHint, templates: settings.templates, now: now) else { return .unrecognized }
        guard settings.currency.uppercased() == "VND" else { return .unsupportedCurrency }

        let id = idPrefix + alert.dedupeKey
        if try isAlreadyRecorded(id: id, alert: alert, in: context)
            || inbox.containsMatch(id: id, signedAmount: alert.signedAmount, date: alert.date, window: duplicateWindow) {
            return .duplicate
        }

        let walletId = settings.walletId(for: alert.bank)
        // Free users get "other" (listed in Uncategorized); Premium users get
        // rules, history, the merchant dictionary and AI. See BankAlertCategorizer.
        var categoryId = BankAlertCategorizer.fallbackCategoryId(for: alert.type)
        if let categorizer {
            categoryId = await categorizer.categorize(alert, in: context).categoryId
            // The AI call can take a moment; the same alert may have arrived
            // by another channel meanwhile.
            if try isAlreadyRecorded(id: id, alert: alert, in: context)
                || inbox.containsMatch(id: id, signedAmount: alert.signedAmount, date: alert.date, window: duplicateWindow) {
                return .duplicate
            }
        }

        guard alert.isVerified, !settings.alwaysReview else {
            let templateId = settings.templates.first { $0.id == alert.bank?.id }?.id
            let pending = PendingBankAlert(
                id: id, bankId: alert.bank?.id, bankName: alert.bank?.name, templateId: templateId,
                type: alert.type, amount: alert.amount,
                date: alert.date, note: alert.note, categoryId: categoryId,
                walletId: walletId, receivedAt: now
            )
            inbox.add(pending)
            return .queued(pending)
        }

        let transaction = Transaction(
            id: id,
            amount: alert.amount,
            note: alert.note,
            categoryId: categoryId,
            walletId: walletId,
            type: alert.type,
            date: alert.date,
            // Never keep the alert itself: it holds the account number and balance.
            rawInput: nil,
            confidence: 1.0
        )
        try TransactionPersistence.create(
            transaction,
            modelContext: context,
            balanceService: balanceService ?? makeBalanceService(context)
        )
        return .saved(transaction)
    }

    // MARK: - Review list

    /// Saves a reviewed item, with the user's edits when given, and removes it
    /// from the list.
    @discardableResult
    static func approve(
        _ item: PendingBankAlert,
        edited: Transaction? = nil,
        in context: ModelContext,
        inbox: BankAlertInbox,
        templates: BankAlertTemplateStore? = nil,
        balanceService: BalanceService? = nil
    ) throws -> Transaction {
        let transaction = edited ?? item.makeTransaction()
        if let templateId = item.templateId, let templates {
            // A template earns trust only when what it read needed no fixing.
            let corrected = transaction.amount != item.amount || transaction.type != item.type
            if corrected {
                templates.recordCorrection(id: templateId)
            } else {
                templates.recordApproval(id: templateId)
            }
        }
        let id = item.id
        transaction.id = id
        transaction.rawInput = nil
        var existing = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        existing.fetchLimit = 1
        if try context.fetchCount(existing) == 0 {
            try TransactionPersistence.create(
                transaction,
                modelContext: context,
                balanceService: balanceService ?? makeBalanceService(context)
            )
        }
        inbox.remove(id: item.id)
        return transaction
    }

    static func discard(_ item: PendingBankAlert, inbox: BankAlertInbox) {
        inbox.remove(id: item.id)
    }

    // MARK: - Private

    private static func makeBalanceService(_ context: ModelContext) -> BalanceService {
        BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
    }

    /// Same id, or a bank-alert transaction with the same signed amount within
    /// `duplicateWindow` (the same alert by SMS after the notification).
    private static func isAlreadyRecorded(id: String, alert: BankAlert, in context: ModelContext) throws -> Bool {
        var byId = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        byId.fetchLimit = 1
        if try context.fetchCount(byId) > 0 { return true }

        let amount = alert.amount
        let from = alert.date.addingTimeInterval(-duplicateWindow)
        let to = alert.date.addingTimeInterval(duplicateWindow)
        let prefix = idPrefix
        let nearby = try context.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.amount == amount && $0.date >= from && $0.date <= to }
        ))
        return nearby.contains { $0.type == alert.type && $0.id.hasPrefix(prefix) }
    }

}

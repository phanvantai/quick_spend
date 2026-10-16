import Foundation
import SwiftData

/// Pure (no-UI) pipeline used by `AddExpenseIntent`. Separated so the parse-and-save
/// logic can be unit-tested without going through App Intents UI hooks.
@MainActor
enum AddExpenseFlow {

    /// Fetch categories, guard the daily limit, run the parser. Throws when there
    /// is nothing to confirm — the intent surfaces these as user-facing dialogs.
    /// `language` is the user's app language; embedded in thrown errors so Siri
    /// reads them in the language the user picked inside QuickSpend rather than
    /// the device locale.
    static func parse(
        input: String,
        in context: ModelContext,
        language: String,
        currency: String,
        parser: ExpenseParsing,
        usage: UsageLimitService,
        defaultWalletId: String = Wallet.personalID
    ) async throws -> [ParsedTransaction] {
        guard usage.canParse else {
            throw AddExpenseError.limitReached(language: language)
        }

        let categories = try context.fetch(FetchDescriptor<Category>())
        guard !categories.isEmpty else {
            throw AddExpenseError.noCategories(language: language)
        }

        let wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []
        let results = await parser.parse(
            input: input,
            categories: categories,
            language: language,
            wallets: wallets.filter { !$0.isArchived },
            defaultWalletId: defaultWalletId,
            currency: currency,
            usageLimitService: usage
        )

        guard !results.isEmpty else {
            throw AddExpenseError.couldNotParse(language: language)
        }
        // Siri cannot ask which wallets to use, so send unclear transfers to the app.
        guard !results.contains(where: \.isIncompleteTransfer) else {
            throw AddExpenseError.incompleteTransfer(language: language)
        }
        return results
    }

    /// Insert and persist each parsed transaction (two legs for a transfer) in
    /// one save. Returns the created models.
    @discardableResult
    static func save(
        parsed: [ParsedTransaction],
        rawInput: String,
        in context: ModelContext,
        walletId: String = Wallet.personalID,
        balanceService: BalanceService? = nil
    ) throws -> [Transaction] {
        let withInput = parsed.map { item -> ParsedTransaction in
            var item = item
            item.rawInput = rawInput
            return item
        }
        let saved = try VoiceTransactionBuilder.transactions(from: withInput, defaultWalletId: walletId)
        let balanceService = balanceService ?? BalanceService(
            modelContext: context,
            autoObserve: false,
            autoCompute: false
        )
        try TransactionPersistence.createMany(
            saved,
            modelContext: context,
            balanceService: balanceService
        )
        return saved
    }
}

enum AddExpenseError: LocalizedError {
    case limitReached(language: String)
    case couldNotParse(language: String)
    case noCategories(language: String)
    case saveFailed(language: String)
    case incompleteTransfer(language: String)

    var errorDescription: String? {
        switch self {
        case .limitReached(let language):
            return L10n.tr("intent.error.limit_reached", language)
        case .couldNotParse(let language):
            return L10n.tr("intent.error.could_not_parse", language)
        case .noCategories(let language):
            return L10n.tr("intent.error.no_categories", language)
        case .saveFailed(let language):
            return L10n.tr("intent.error.save_failed", language)
        case .incompleteTransfer(let language):
            return L10n.tr("intent.error.incomplete_transfer", language)
        }
    }
}

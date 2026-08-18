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
        usage: UsageLimitService
    ) async throws -> [ParsedTransaction] {
        guard usage.canParse else {
            throw AddExpenseError.limitReached(language: language)
        }

        let categories = try context.fetch(FetchDescriptor<Category>())
        guard !categories.isEmpty else {
            throw AddExpenseError.noCategories(language: language)
        }

        let results = await parser.parse(
            input: input,
            categories: categories,
            language: language,
            currency: currency,
            usageLimitService: usage
        )

        guard !results.isEmpty else {
            throw AddExpenseError.couldNotParse(language: language)
        }
        return results
    }

    /// Insert and persist each parsed transaction. Returns the created models so
    /// the caller can build a success dialog summarising what was saved.
    @discardableResult
    static func save(
        parsed: [ParsedTransaction],
        rawInput: String,
        in context: ModelContext,
        walletId: String = Wallet.personalID
    ) throws -> [Transaction] {
        var saved: [Transaction] = []
        for item in parsed {
            let transaction = Transaction(
                amount: item.amount,
                note: item.note,
                categoryId: item.categoryId,
                walletId: walletId,
                type: item.type,
                date: item.date,
                rawInput: rawInput,
                confidence: item.confidence
            )
            context.insert(transaction)
            saved.append(transaction)
        }
        try context.save()
        return saved
    }
}

enum AddExpenseError: LocalizedError {
    case limitReached(language: String)
    case couldNotParse(language: String)
    case noCategories(language: String)
    case saveFailed(language: String)

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
        }
    }
}

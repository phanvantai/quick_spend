import AppIntents
import SwiftData
import SwiftUI
import UIKit

/// Lets Siri / Shortcuts run the full voice-to-expense pipeline without opening
/// the app: receives a transcribed description (typically from a Dictate Text
/// action), parses with Gemini, and either auto-saves (when the parser is very
/// confident) or shows a confirmation card.
///
/// Auto-save: when EVERY parsed transaction's confidence is at or above
/// `autoSaveConfidenceThreshold`, we skip the confirmation card and return a
/// result with a snippet view + spoken dialog. iOS shows the snippet briefly
/// then dismisses — the user gets visual + spoken confirmation without having
/// to tap "Log". Anything below the threshold falls back to the explicit
/// confirmation card so the user can review.
///
/// Note on button labels: "Cancel" / "Log" come from iOS's `ConfirmationActionName`
/// system and are localized by the device locale, not by the user's app-language
/// preference. We control the dialog text and snippet content though, so those
/// honour `AppConfig.language`.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"

    static var description = IntentDescription(
        "Log an expense or income using natural language. QuickSpend parses the amount, category, and date for you."
    )

    static var openAppWhenRun: Bool = false

    /// Skip the Siri confirmation card when every parsed transaction is at
    /// least this confident. Below this we still show the card so the user
    /// can catch a bad parse before it lands.
    static let autoSaveConfidenceThreshold: Double = 0.9

    /// Injection point for tests; production resolves to the Gemini-backed parser.
    @MainActor static var parser: ExpenseParsing = GeminiExpenseParser()

    @Parameter(
        title: "Expense",
        description: "What did you spend on? Include the amount.",
        requestValueDialog: IntentDialog("What expense should I add?")
    )
    var expenseDescription: String

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView & ProvidesDialog {
        IntentEnvironment.ensureParserReady()

        let container = try IntentEnvironment.container()
        let context = ModelContext(container)
        _ = try? WalletService.bootstrapIfNeeded(modelContext: context)
        let config = IntentEnvironment.currentConfig()
        let usage = await IntentEnvironment.makeUsageLimitService()

        let parsed = try await AddExpenseFlow.parse(
            input: expenseDescription,
            in: context,
            language: config.language,
            currency: config.currency,
            parser: Self.parser,
            usage: usage
        )

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let snippet = ParsedExpenseSnippetView(items: parsed, categories: categories, config: config)

        // High-confidence parses skip the confirm card entirely — Siri reads
        // the success line and shows the snippet for a beat, then dismisses.
        if Self.shouldAutoSave(parsed) {
            try saveOrThrow(parsed: parsed, in: context, language: config.language)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return .result(dialog: autoSavedDialog(for: parsed, config: config)) {
                snippet
            }
        }

        do {
            try await requestConfirmation(
                actionName: .log,
                dialog: confirmationDialog(for: parsed, config: config)
            ) {
                snippet
            }
        } catch {
            // User cancelled the confirmation card — exit silently, no extra popup.
            return .result(dialog: IntentDialog("")) { EmptyView() }
        }

        try saveOrThrow(parsed: parsed, in: context, language: config.language)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return .result(dialog: autoSavedDialog(for: parsed, config: config)) {
            snippet
        }
    }

    /// True when every parsed transaction meets the auto-save threshold.
    /// One ambiguous item drops the whole batch into the confirm-card path
    /// so the user can still cancel.
    static func shouldAutoSave(_ parsed: [ParsedTransaction]) -> Bool {
        guard !parsed.isEmpty else { return false }
        return parsed.allSatisfy { $0.confidence >= autoSaveConfidenceThreshold }
    }

    @MainActor
    private func saveOrThrow(parsed: [ParsedTransaction], in context: ModelContext, language: String) throws {
        do {
            try AddExpenseFlow.save(
                parsed: parsed,
                rawInput: expenseDescription,
                in: context,
                walletId: PreferencesService.shared.defaultWalletId
            )
        } catch {
            throw AddExpenseError.saveFailed(language: language)
        }
    }

    private func confirmationDialog(for parsed: [ParsedTransaction], config: AppConfig) -> IntentDialog {
        let language = config.language
        if parsed.count == 1, let first = parsed.first {
            let amount = config.formatCurrency(first.amount)
            let format = L10n.tr("intent.confirm_one", language)
            return IntentDialog(stringLiteral: String(format: format, amount, first.note))
        }
        let format = L10n.tr("intent.confirm_many", language)
        return IntentDialog(stringLiteral: String(format: format, parsed.count))
    }

    private func autoSavedDialog(for parsed: [ParsedTransaction], config: AppConfig) -> IntentDialog {
        let language = config.language
        if parsed.count == 1, let first = parsed.first {
            let amount = config.formatCurrency(first.amount)
            let format = L10n.tr("intent.auto_saved_one", language)
            return IntentDialog(stringLiteral: String(format: format, amount, first.note))
        }
        let format = L10n.tr("intent.auto_saved_many", language)
        return IntentDialog(stringLiteral: String(format: format, parsed.count))
    }
}

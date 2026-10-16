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
    static let autoSaveConfidenceThreshold = VoiceAutoSavePolicy.confidenceThreshold

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
        let wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []
        let defaultWalletId = WalletService.resolvedDefaultWalletId(wallets: wallets)

        let parsed = try await AddExpenseFlow.parse(
            input: expenseDescription,
            in: context,
            language: config.language,
            currency: config.currency,
            parser: Self.parser,
            usage: usage,
            defaultWalletId: defaultWalletId
        )

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let snippet = ParsedExpenseSnippetView(items: parsed, categories: categories, wallets: wallets, config: config)

        // High-confidence parses skip the confirm card entirely — Siri reads
        // the success line and shows the snippet for a beat, then dismisses.
        if Self.shouldAutoSave(parsed) {
            try saveOrThrow(parsed: parsed, in: context, walletId: defaultWalletId, language: config.language)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return .result(dialog: IntentDialog(stringLiteral: VoiceSummary.saved(parsed, wallets: wallets, config: config))) {
                snippet
            }
        }

        do {
            try await requestConfirmation(
                actionName: .log,
                dialog: IntentDialog(stringLiteral: VoiceSummary.confirmation(parsed, wallets: wallets, config: config))
            ) {
                snippet
            }
        } catch {
            // User cancelled the confirmation card — exit silently, no extra popup.
            return .result(dialog: IntentDialog("")) { EmptyView() }
        }

        try saveOrThrow(parsed: parsed, in: context, walletId: defaultWalletId, language: config.language)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return .result(dialog: IntentDialog(stringLiteral: VoiceSummary.saved(parsed, wallets: wallets, config: config))) {
            snippet
        }
    }

    /// True when every parsed transaction meets the auto-save threshold.
    /// One ambiguous item drops the whole batch into the confirm-card path
    /// so the user can still cancel.
    static func shouldAutoSave(_ parsed: [ParsedTransaction]) -> Bool {
        VoiceAutoSavePolicy.shouldAutoSave(parsed)
    }

    @MainActor
    private func saveOrThrow(parsed: [ParsedTransaction], in context: ModelContext, walletId: String, language: String) throws {
        do {
            try AddExpenseFlow.save(
                parsed: parsed,
                rawInput: expenseDescription,
                in: context,
                walletId: walletId
            )
        } catch {
            throw AddExpenseError.saveFailed(language: language)
        }
    }
}

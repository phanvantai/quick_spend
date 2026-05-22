import AppIntents
import SwiftData
import SwiftUI
import UIKit

/// Lets Siri / Shortcuts run the full voice-to-expense pipeline without opening
/// the app: receives a transcribed description (typically from a Dictate Text
/// action), parses with Gemini, shows the parsed transactions inside the
/// confirmation card, and saves on confirm — silent on success.
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

    /// Injection point for tests; production resolves to the Gemini-backed parser.
    @MainActor static var parser: ExpenseParsing = GeminiExpenseParser()

    @Parameter(
        title: "Expense",
        description: "What did you spend on? Include the amount.",
        requestValueDialog: IntentDialog("What expense should I add?")
    )
    var expenseDescription: String

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentEnvironment.ensureParserReady()

        let container = try IntentEnvironment.container()
        let context = ModelContext(container)
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

        do {
            try await requestConfirmation(
                actionName: .log,
                dialog: confirmationDialog(for: parsed, config: config)
            ) {
                snippet
            }
        } catch {
            // User cancelled the confirmation card — exit silently, no extra popup.
            return .result()
        }

        do {
            try AddExpenseFlow.save(parsed: parsed, rawInput: expenseDescription, in: context)
        } catch {
            throw AddExpenseError.saveFailed(language: config.language)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return .result()
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
}

import AppIntents
import SwiftData

/// Records the transaction in a bank balance alert. Meant to run from a
/// Shortcuts automation (iOS 27 Notification trigger on the banking app, or the
/// Message / Email triggers for bank SMS and email) with no UI: it never opens
/// the app, never asks a question and never calls the network.
///
/// Text it does not recognise (OTP, promotions) is ignored silently, so the
/// automation can safely run on every notification from the bank.
struct AddBankAlertIntent: AppIntent {
    static var title: LocalizedStringResource = "Add from Bank Alert"

    static var description = IntentDescription(
        "Records the income or expense in a bank balance alert. Use it in an automation that runs when your banking app sends a notification. The alert text is read on the device and never stored."
    )

    static var openAppWhenRun: Bool = false

    /// Optional so an automation that passes nothing finishes quietly instead
    /// of stopping to ask for a value.
    @Parameter(
        title: "Alert Text",
        description: "The text of the bank notification, SMS or email.",
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var alertText: String?

    /// Which bank sent it, for SMS and email whose text may not name the bank.
    @Parameter(
        title: "Bank",
        description: "Choose the bank when the alert text doesn't name it, for example in bank SMS."
    )
    var bank: BankAlertBankOption?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentEnvironment.container()
        let context = ModelContext(container)
        _ = try? WalletService.bootstrapIfNeeded(modelContext: context)
        let config = IntentEnvironment.currentConfig()
        let wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []

        let preferences = PreferencesService.shared
        let isPremium = await IntentEnvironment.resolvePremiumStatus()
        if isPremium && preferences.bankAlertsUseAI { IntentEnvironment.ensureParserReady() }
        let categorizer = BankAlertCategorizer(
            isPremium: isPremium,
            useAI: preferences.bankAlertsUseAI,
            rules: .shared,
            ai: GeminiCategorizer(),
            language: config.language
        )

        let result = try await BankAlertImportFlow.importAlert(
            text: alertText ?? "",
            bankHint: bank?.bank,
            settings: .current(wallets: wallets),
            in: context,
            inbox: .shared,
            categorizer: categorizer
        )
        return .result(dialog: IntentDialog(stringLiteral: BankAlertSummary.dialog(for: result, config: config)))
    }
}

/// Banks the Shortcuts action can be told about.
enum BankAlertBankOption: String, AppEnum {
    case vietcombank

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bank"
    static var caseDisplayRepresentations: [BankAlertBankOption: DisplayRepresentation] = [
        .vietcombank: "Vietcombank",
    ]

    var bank: BankInfo {
        switch self {
        case .vietcombank: return .vietcombank
        }
    }
}

/// What the automation shows after it runs. Empty for alerts that were
/// skipped, so promotions and repeats don't pop anything up.
enum BankAlertSummary {
    static func dialog(for result: BankAlertImportResult, config: AppConfig) -> String {
        switch result {
        case .saved(let transaction):
            let key = transaction.type == .income ? "bank_alert.saved_income" : "bank_alert.saved_expense"
            return L10n.tr(key, config.language, config.formatCurrency(transaction.amount), transaction.note)
        case .queued(let item):
            let key = item.type == .income ? "bank_alert.queued_income" : "bank_alert.queued_expense"
            return L10n.tr(key, config.language, config.formatCurrency(item.amount), item.note)
        case .unsupportedCurrency:
            return L10n.tr("bank_alert.unsupported_currency", config.language)
        case .duplicate, .unrecognized, .disabled:
            return ""
        }
    }
}

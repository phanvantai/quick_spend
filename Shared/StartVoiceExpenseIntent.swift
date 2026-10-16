import AppIntents

/// Opens QuickSpend and starts voice recording. Used by the Control Center /
/// Lock Screen control; it lives in both the app and the widget extension so
/// the system can run it in the app after opening it.
struct StartVoiceExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.voice_expense.title"
    static var description = IntentDescription("intent.voice_expense.description")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickLaunchCenter.shared.request(.voiceExpense)
        return .result()
    }
}

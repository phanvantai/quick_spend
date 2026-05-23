import AppIntents

/// Registers QuickSpend's App Intents with Siri and Shortcuts. The phrases here
/// seed `AppShortcuts.xcstrings` on the first build; localised vi/ja/es phrases
/// live there.
///
/// Apple's `AppShortcutsProvider` only allows parameterized phrases when the
/// parameter is an `AppEntity` or `AppEnum` — plain `String` parameters cannot
/// be inlined. So every phrase below is "open-ended": Siri triggers the intent
/// without a value, then asks `requestValueDialog` ("What expense should I
/// add?") to capture the description. For one-shot single-utterance voice the
/// user installs the bundled "Quick Expense" Shortcut, which chains a Dictate
/// Text action into the same intent.
struct QuickSpendShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Record expense in \(.applicationName)",
                "Track spending in \(.applicationName)",
                "Quick expense in \(.applicationName)",
                "New expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}

import SwiftUI
import SwiftData

/// Settings screen with grouped sections.
///
/// v3.0: presented as a sheet from the Home/Transactions toolbar gear icon,
/// not a root tab. A Done button in the toolbar closes the sheet.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    @Query private var transactions: [Transaction]

    /// Driven by `SubscriptionSection` so the global overlay covers the whole sheet.
    @State private var isRestoring = false

    /// Currency cannot be changed once transactions exist to prevent data integrity issues.
    private var isCurrencyLocked: Bool {
        !transactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                CoreSection(isCurrencyLocked: isCurrencyLocked)
                SubscriptionSection(globalIsRestoring: $isRestoring)
                DataSection()
                PreferencesSection()
            }
            .navigationTitle(L10n.tr("settings.title", appConfig.language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isRestoring {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
        .environment(CloudSyncService())
}

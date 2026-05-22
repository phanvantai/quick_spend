import SwiftUI
import SwiftData

/// Main container with bottom tab bar and center voice FAB.
///
/// v3.0: Settings is no longer a tab — it's a sheet opened from the toolbar
/// gear icon on Home and Transactions. This frees a tab slot and matches the
/// Siri-first ethos where the primary surfaces are read views, not config.
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                Tab(L10n.tr("home.title", appConfig.language), systemImage: "house.fill", value: 0) {
                    HomeView()
                }
                Tab(L10n.tr("transactions.title", appConfig.language), systemImage: "list.bullet.rectangle.fill", value: 1) {
                    TransactionsView()
                }
            }
            .tint(AppTheme.adaptiveAccent(colorScheme))

            VoiceFABLayer()
        }
        .tint(AppTheme.adaptiveAccent(colorScheme))
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

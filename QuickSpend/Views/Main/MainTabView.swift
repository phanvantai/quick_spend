import SwiftUI
import SwiftData

/// Main container with bottom tab bar
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
            }
            Tab("Transactions", systemImage: "calendar", value: 1) {
                TransactionsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        //.tabBarMinimizeBehavior(.onScrollDown)
        .tint(AppTheme.primaryMint)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

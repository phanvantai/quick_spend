import SwiftUI
import SwiftData

/// Root view — shows splash screen which handles all launch routing
struct ContentView: View {
    var body: some View {
        SplashView()
    }
}

#Preview("Main View") {
    let config = AppConfigViewModel()
    config.completeOnboarding()
    return ContentView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(config)
        .environment(SubscriptionViewModel())
        .environment(CloudSyncService())
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
        .environment(CloudSyncService())
}

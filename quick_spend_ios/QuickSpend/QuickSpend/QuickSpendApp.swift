import SwiftUI
import SwiftData
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct QuickSpendApp: App {
    @State private var appConfig = AppConfigViewModel()
    @State private var subscription = SubscriptionViewModel()

    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        AnalyticsService.initialize()
        GeminiParserService.initialize()
        subscription.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appConfig)
                .environment(subscription)
                .preferredColorScheme(appConfig.colorScheme)
        }
        .modelContainer(for: [
            Expense.self,
            QuickCategory.self,
            RecurringTemplate.self,
        ])
    }
}

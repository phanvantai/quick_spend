import SwiftUI
import SwiftData

@main
struct QuickSpendApp: App {
    @State private var appConfig = AppConfigViewModel()
    @State private var subscription = SubscriptionViewModel()

    init() {
        AnalyticsService.initialize()
        GeminiParserService.initialize()
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

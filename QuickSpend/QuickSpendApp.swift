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
        Self._resetStoreIfNeeded()
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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    appConfig.syncLanguageFromSystem()
                }
                .task {
                    appConfig.syncLanguageFromSystem()
                }
        }
        .modelContainer(for: [
            Transaction.self,
            Category.self,
            RecurringTemplate.self,
        ])
    }

    /// Reset SwiftData store when upgrading from v1 to v2 (clean start migration)
    private static func _resetStoreIfNeeded() {
        let key = "hasCompletedV2Migration"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let storeURL = appSupport.appendingPathComponent("default.store")
        try? FileManager.default.removeItem(at: storeURL)

        // Reset onboarding so categories get re-seeded
        PreferencesService.shared.resetOnboarding()
        UserDefaults.standard.set(true, forKey: key)
        print("[QuickSpendApp] V2 migration: reset SwiftData store")
    }
}

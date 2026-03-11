import SwiftUI
import SwiftData

/// Root view — routes to onboarding or main tab view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig

    /// Track the last-known language so we can update categories when it changes
    @State private var lastSyncedLanguage: String?

    var body: some View {
        if appConfig.isOnboardingComplete {
            MainTabView()
                .onAppear {
                    CategoryService.seedCategoriesIfNeeded(
                        language: appConfig.language,
                        modelContext: modelContext
                    )
                    // Generate pending recurring transactions on each launch
                    let _ = RecurringService.generatePendingTransactions(modelContext: modelContext)
                    lastSyncedLanguage = appConfig.language
                }
                .onChange(of: appConfig.language) { _, newLanguage in
                    // When language changes (e.g. synced from iOS Settings), update category names
                    if lastSyncedLanguage != newLanguage {
                        CategoryService.updateCategoryNames(
                            language: newLanguage,
                            modelContext: modelContext
                        )
                        lastSyncedLanguage = newLanguage
                    }
                }
        } else {
            OnboardingView {
                // Categories are seeded inside OnboardingView
            }
        }
    }
}

#Preview("Main View") {
    let config = AppConfigViewModel()
    config.completeOnboarding()
    return ContentView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(config)
        .environment(SubscriptionViewModel())
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

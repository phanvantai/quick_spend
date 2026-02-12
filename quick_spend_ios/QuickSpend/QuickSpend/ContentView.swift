import SwiftUI
import SwiftData

/// Root view — routes to onboarding or main tab view
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig

    var body: some View {
        if appConfig.isOnboardingComplete {
            MainTabView()
                .onAppear {
                    CategoryService.seedSystemCategoriesIfNeeded(
                        language: appConfig.language,
                        modelContext: modelContext
                    )
                    // Generate pending recurring expenses on each launch
                    let _ = RecurringService.generatePendingExpenses(modelContext: modelContext)
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
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(config)
        .environment(SubscriptionViewModel())
}

#Preview("Onboarding") {
    ContentView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

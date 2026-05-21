import SwiftUI
import SwiftData

/// Branded splash screen that handles all launch-time async work.
/// Shows the app icon and name while waiting for CloudKit sync,
/// checking for synced data, and generating recurring transactions.
struct SplashView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(CloudSyncService.self) private var cloudSync

    /// True once all launch work has completed and the minimum display time has elapsed
    @State private var isLaunchComplete = false

    // Entrance animation state
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    /// Track language changes for category name updates (persists across app lifecycle)
    @State private var lastSyncedLanguage: String?

    var body: some View {
        Group {
            if isLaunchComplete {
                destinationView
                    .transition(.opacity)
            } else {
                splashContent
                    .transition(.opacity)
                    .task {
                        await performLaunchWork()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLaunchComplete)
    }

    // MARK: - Destination Routing

    @ViewBuilder
    private var destinationView: some View {
        if appConfig.isOnboardingComplete {
            MainTabView()
                .onAppear {
                    lastSyncedLanguage = appConfig.language
                }
                .onChange(of: appConfig.language) { _, newLanguage in
                    if lastSyncedLanguage != newLanguage {
                        CategoryService.updateCategoryNames(
                            language: newLanguage,
                            modelContext: modelContext
                        )
                        lastSyncedLanguage = newLanguage
                    }
                }
                // Existing v2.4 users have isOnboardingComplete=true but never saw
                // the balance step. AppConfig's forward-compat decoder defaults
                // their hasSeenBalanceWhatsNew to false, so the modal fires once.
                // Fresh installs flip both flags atomically in completeOnboarding,
                // so they never see it.
                .sheet(isPresented: Binding(
                    get: { !appConfig.hasSeenBalanceWhatsNew },
                    set: { _ in /* dismiss flows through markBalanceWhatsNewSeen */ }
                )) {
                    WhatsNewBalanceModal()
                }
        } else {
            OnboardingView { }
        }
    }

    // MARK: - Splash Content

    private var splashContent: some View {
        ZStack {
            splashBackground
                .ignoresSafeArea()

            VStack(spacing: AppTheme.spacing16) {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "wallet.bifold.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Text("Quick Spend")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                textOpacity = 1.0
            }
        }
    }

    private var splashBackground: some View {
        LinearGradient(
            colors: [Color(hex: "1B4332"), Color(hex: "0A1F14")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Launch Work

    @MainActor
    private func performLaunchWork() async {
        async let minimumDisplay: () = safeSleep(seconds: 1.5)
        async let launchWork: () = executeLaunchSequence()

        _ = await (minimumDisplay, launchWork)

        isLaunchComplete = true
    }

    private func safeSleep(seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    @MainActor
    private func executeLaunchSequence() async {
        // Step 1: Wait for CloudKit initial import to complete
        await waitForCloudImport()

        // Step 2: Remove any duplicate categories caused by seed + CloudKit race condition
        CategoryService.deduplicateCategoriesIfNeeded(modelContext: modelContext)

        // Step 3: If onboarding not done, check if synced data allows skipping it
        if !appConfig.isOnboardingComplete {
            checkSyncedDataAndSkipOnboarding()
        }

        // Step 4: Generate recurring transactions if onboarding is complete
        if appConfig.isOnboardingComplete {
            let _ = RecurringService.generatePendingTransactions(modelContext: modelContext)
        }
    }

    @MainActor
    private func waitForCloudImport() async {
        guard !cloudSync.hasCompletedInitialImport else { return }
        while !cloudSync.hasCompletedInitialImport {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Synced Data Check

    /// After CloudKit initial import completes, check if data was synced from another device.
    /// If so, skip onboarding and restore preferences from the synced categories.
    @MainActor
    private func checkSyncedDataAndSkipOnboarding() {
        let categoryCount = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
        let transactionCount = (try? modelContext.fetchCount(FetchDescriptor<Transaction>())) ?? 0

        if categoryCount > 0 || transactionCount > 0 {
            inferPreferencesFromSyncedData()
            appConfig.completeOnboarding()
            // No anchor seed: if CloudKit eventually syncs an anchor from the
            // other device, the BalanceService observer (which now filters for
            // BalanceAnchor changes too) will recompute. Until then the card
            // shows the Setup CTA — better than a zero seed racing against
            // delayed CloudKit batches.
        }
    }

    /// Detect the language from synced category names and the currency
    /// from synced transaction amounts to restore user preferences.
    private func inferPreferencesFromSyncedData() {
        if let inferredLanguage = inferLanguageFromCategories() {
            appConfig.updatePreferences(
                language: inferredLanguage,
                currency: LanguageOption.defaultCurrency(for: inferredLanguage)
            )
        }
    }

    /// Check category names against known localized names to determine the language.
    /// Returns the language code if confidently detected, nil otherwise.
    private func inferLanguageFromCategories() -> String? {
        let descriptor = FetchDescriptor<Category>()
        guard let categories = try? modelContext.fetch(descriptor),
              !categories.isEmpty else { return nil }

        // Count how many category names match each language
        let languages = ["en", "vi", "ja", "es"]
        var scores: [String: Int] = [:]

        for language in languages {
            var count = 0
            for category in categories {
                let expectedName = CategoryService.categoryName(for: category.id, language: language)
                if category.name == expectedName {
                    count += 1
                }
            }
            scores[language] = count
        }

        // Pick the language with the most matching names
        guard let best = scores.max(by: { $0.value < $1.value }),
              best.value > 0 else { return nil }

        return best.key
    }
}

// MARK: - Previews

#Preview("Splash") {
    SplashView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
        .environment(CloudSyncService())
}

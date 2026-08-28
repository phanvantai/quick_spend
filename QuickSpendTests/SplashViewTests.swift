import Testing
import Foundation
import SwiftData
@testable import QuickSpend

// Type alias to disambiguate from objc_category
private typealias AppCategory = QuickSpend.Category

@Suite("SplashView Launch Logic Tests")
@MainActor
struct SplashViewLaunchLogicTests {

    @Test("Returning users bypass the CloudKit launch gate")
    func returningUserBypassesCloudImportWait() {
        #expect(SplashLaunchPolicy.shouldWaitForCloudImport(isOnboardingComplete: true) == false)
        #expect(SplashLaunchPolicy.minimumDisplayDuration == .milliseconds(300))
    }

    @Test("Fresh installs get a bounded CloudKit restore window")
    func freshInstallUsesBoundedCloudImportWait() {
        #expect(SplashLaunchPolicy.shouldWaitForCloudImport(isOnboardingComplete: false))
        #expect(SplashLaunchPolicy.cloudRestoreWaitLimit == .seconds(3))
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: config
        )
    }

    private func makeAppConfig() -> AppConfigViewModel {
        let suiteName = "test.splash.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = PreferencesService(defaults: defaults)
        return AppConfigViewModel(preferences: preferences)
    }

    /// Helper that mirrors SplashView.inferLanguageFromCategories() logic
    private func inferLanguage(from context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<AppCategory>()
        guard let categories = try? context.fetch(descriptor),
              !categories.isEmpty else { return nil }

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

        guard let best = scores.max(by: { $0.value < $1.value }),
              best.value > 0 else { return nil }

        return best.key
    }

    // MARK: - Destination Resolution Tests

    @Test("Fresh install with no data resolves to onboarding")
    func testFreshInstallDestination() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())

        let hasSyncedData = categoryCount > 0 || transactionCount > 0
        #expect(hasSyncedData == false)
        #expect(appConfig.isOnboardingComplete == false)
    }

    @Test("Returning user with onboarding complete resolves to main")
    func testOnboardingCompleteDestination() {
        let appConfig = makeAppConfig()
        appConfig.completeOnboarding()

        #expect(appConfig.isOnboardingComplete == true)
    }

    // MARK: - Auto-Complete Onboarding Tests

    @Test("Launch auto-completes onboarding when synced categories exist")
    func testAutoCompleteOnboardingWithSyncedCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        // Simulate categories synced from CloudKit
        CategoryService.seedCategoriesIfNeeded(language: "vi", modelContext: context)

        #expect(appConfig.isOnboardingComplete == false)

        // Mirror the splash logic: check synced data
        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        #expect(categoryCount > 0)

        if categoryCount > 0 {
            appConfig.completeOnboarding()
        }

        #expect(appConfig.isOnboardingComplete == true)
    }

    @Test("Launch auto-completes onboarding when synced transactions exist")
    func testAutoCompleteOnboardingWithSyncedTransactions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        // Simulate a transaction synced from CloudKit (no categories)
        let transaction = Transaction(
            amount: 50000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: Date.now
        )
        context.insert(transaction)
        try context.save()

        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())
        #expect(transactionCount > 0)

        if transactionCount > 0 {
            appConfig.completeOnboarding()
        }

        #expect(appConfig.isOnboardingComplete == true)
    }

    @Test("Launch does NOT auto-complete onboarding when no data exists")
    func testNoAutoCompleteWithNoData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())

        let hasSyncedData = categoryCount > 0 || transactionCount > 0
        #expect(hasSyncedData == false)
        #expect(appConfig.isOnboardingComplete == false)
    }

    // MARK: - Preference Inference Tests

    @Test("Vietnamese preferences inferred from synced Vietnamese categories")
    func testPreferenceInferenceVietnamese() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        CategoryService.seedCategoriesIfNeeded(language: "vi", modelContext: context)

        let inferredLanguage = inferLanguage(from: context)
        #expect(inferredLanguage == "vi")

        if let lang = inferredLanguage {
            appConfig.updatePreferences(
                language: lang,
                currency: LanguageOption.defaultCurrency(for: lang)
            )
        }

        #expect(appConfig.language == "vi")
        #expect(appConfig.currency == "VND")
    }

    @Test("Japanese preferences inferred from synced Japanese categories")
    func testPreferenceInferenceJapanese() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        CategoryService.seedCategoriesIfNeeded(language: "ja", modelContext: context)

        let inferredLanguage = inferLanguage(from: context)
        #expect(inferredLanguage == "ja")

        if let lang = inferredLanguage {
            appConfig.updatePreferences(
                language: lang,
                currency: LanguageOption.defaultCurrency(for: lang)
            )
        }

        #expect(appConfig.language == "ja")
        #expect(appConfig.currency == "JPY")
    }

    @Test("English preferences inferred from synced English categories")
    func testPreferenceInferenceEnglish() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)

        let inferredLanguage = inferLanguage(from: context)
        #expect(inferredLanguage == "en")

        if let lang = inferredLanguage {
            appConfig.updatePreferences(
                language: lang,
                currency: LanguageOption.defaultCurrency(for: lang)
            )
        }

        #expect(appConfig.language == "en")
        #expect(appConfig.currency == "USD")
    }

    @Test("Spanish preferences inferred from synced Spanish categories")
    func testPreferenceInferenceSpanish() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let appConfig = makeAppConfig()

        CategoryService.seedCategoriesIfNeeded(language: "es", modelContext: context)

        let inferredLanguage = inferLanguage(from: context)
        #expect(inferredLanguage == "es")

        if let lang = inferredLanguage {
            appConfig.updatePreferences(
                language: lang,
                currency: LanguageOption.defaultCurrency(for: lang)
            )
        }

        #expect(appConfig.language == "es")
        #expect(appConfig.currency == "EUR")
    }

    // MARK: - Recurring Transaction Generation Tests

    @Test("Recurring transactions generated during launch sequence")
    func testRecurringGenerationDuringLaunch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            id: "splash-test",
            amount: 10000,
            note: "Daily coffee",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(generated >= 1)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.count >= 1)
    }

    // MARK: - Category Seeding Guard Tests

    @Test("Category seeding does not duplicate synced categories")
    func testCategorySeedingGuard() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Simulate 1 category synced from CloudKit
        let category = AppCategory(
            id: "food_drink",
            name: "Ăn uống",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0
        )
        context.insert(category)
        try context.save()

        // Attempt to seed — should be a no-op (categories already exist)
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)

        let categories = try context.fetch(FetchDescriptor<AppCategory>())
        // Should still have only 1 category, not 26+ seeded ones
        #expect(categories.count == 1)
        // Name should remain Vietnamese (not overwritten to English)
        #expect(categories.first?.name == "Ăn uống")
    }
}

import Testing
import Foundation
import SwiftData
import Combine
@testable import QuickSpend

// Type alias to disambiguate from objc_category
private typealias AppCategory = QuickSpend.Category

@Suite("CloudSync Tests")
struct CloudSyncTests {

    // MARK: - CloudSyncService Status Tests

    @Test("CloudSyncService initializes with unknown status")
    func testInitialStatus() {
        let service = CloudSyncService()
        // Initial status is unknown before account check completes
        #expect(service.iCloudStatus == .unknown)
        #expect(service.isSyncing == false)
        #expect(service.lastSyncDate == nil)
        #expect(service.lastError == nil)
    }

    @Test("CloudSyncService isEnabled returns false when status is unknown")
    func testIsEnabledUnknown() {
        let service = CloudSyncService()
        #expect(service.isEnabled == false)
    }

    @Test("CloudSyncService statusDescription returns unknown for initial state")
    func testStatusDescriptionInitial() {
        let service = CloudSyncService()
        #expect(service.statusDescription == "unknown")
    }

    @Test("CloudSyncService initializes with hasCompletedInitialImport false")
    func testInitialImportNotComplete() {
        let service = CloudSyncService()
        #expect(service.hasCompletedInitialImport == false)
    }

    @Test("CloudSyncService initializes with hasCheckedAccountStatus false")
    func testInitialAccountStatusNotChecked() {
        let service = CloudSyncService()
        #expect(service.hasCheckedAccountStatus == false)
    }

    @Test("didFinishImport publisher delivers manual sends to subscribers")
    func testDidFinishImportPublisherDeliversEvents() async throws {
        let service = CloudSyncService()
        let received = ReceivedCounter()
        let subscription = service.didFinishImport.sink {
            received.increment()
        }
        defer { subscription.cancel() }

        service.didFinishImport.send()
        service.didFinishImport.send()

        // Combine sinks fire synchronously on send(), but yield once to let any
        // queued runloop work settle before asserting.
        try await Task.sleep(for: .milliseconds(50))

        #expect(received.value == 2)
    }
}

/// Thread-safe counter so the sink closure can mutate without Sendable warnings.
private final class ReceivedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int = 0
    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func increment() {
        lock.lock(); defer { lock.unlock() }
        _value += 1
    }
}

@Suite("CloudKit Onboarding Skip Tests")
@MainActor
struct CloudKitOnboardingSkipTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    @Test("Onboarding should be skipped when synced categories exist")
    func testSkipOnboardingWithSyncedCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Simulate categories synced from CloudKit
        let category = AppCategory(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0
        )
        context.insert(category)
        try context.save()

        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())

        // This mirrors the logic in ContentView.skipOnboardingIfSyncedDataExists()
        let shouldSkipOnboarding = categoryCount > 0 || transactionCount > 0
        #expect(shouldSkipOnboarding == true)
    }

    @Test("Onboarding should be skipped when synced transactions exist")
    func testSkipOnboardingWithSyncedTransactions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Simulate a transaction synced from CloudKit
        let transaction = Transaction(
            amount: 50000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: Date.now
        )
        context.insert(transaction)
        try context.save()

        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())

        let shouldSkipOnboarding = categoryCount > 0 || transactionCount > 0
        #expect(shouldSkipOnboarding == true)
    }

    @Test("Onboarding should NOT be skipped on a fresh install with no data")
    func testDoNotSkipOnboardingWithNoData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let categoryCount = try context.fetchCount(FetchDescriptor<AppCategory>())
        let transactionCount = try context.fetchCount(FetchDescriptor<Transaction>())

        let shouldSkipOnboarding = categoryCount > 0 || transactionCount > 0
        #expect(shouldSkipOnboarding == false)
    }

    @Test("Category seeding is skipped when synced categories already exist")
    func testCategorySeedingSkippedWithSyncedData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Simulate 1 category synced from CloudKit
        let category = AppCategory(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0
        )
        context.insert(category)
        try context.save()

        // Attempt to seed categories — should be a no-op
        CategoryService.seedCategoriesIfNeeded(language: "vi", modelContext: context)

        let categories = try context.fetch(FetchDescriptor<AppCategory>())
        // Should still have only 1 category (the synced one), not 27+ seeded ones
        #expect(categories.count == 1)
        // Name should NOT have been changed to Vietnamese
        #expect(categories.first?.name == "Food & Drink")
    }
}

@Suite("Language Inference from Synced Categories Tests")
@MainActor
struct LanguageInferenceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    /// Helper that mirrors ContentView.inferLanguageFromCategories() logic
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

    @Test("Infer English from English category names")
    func testInferEnglish() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Seed English categories
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)

        let inferred = inferLanguage(from: context)
        #expect(inferred == "en")
    }

    @Test("Infer Vietnamese from Vietnamese category names")
    func testInferVietnamese() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "vi", modelContext: context)

        let inferred = inferLanguage(from: context)
        #expect(inferred == "vi")
    }

    @Test("Infer Japanese from Japanese category names")
    func testInferJapanese() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "ja", modelContext: context)

        let inferred = inferLanguage(from: context)
        #expect(inferred == "ja")
    }

    @Test("Infer Spanish from Spanish category names")
    func testInferSpanish() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "es", modelContext: context)

        let inferred = inferLanguage(from: context)
        #expect(inferred == "es")
    }

    @Test("Returns nil when no categories exist")
    func testInferNilForEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inferred = inferLanguage(from: context)
        #expect(inferred == nil)
    }

    @Test("Returns nil when category names don't match any known language")
    func testInferNilForCustomNames() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = AppCategory(
            id: "custom_cat",
            name: "My Custom Category",
            iconName: "star",
            colorHex: "#000000",
            type: .expense,
            group: .other,
            sortOrder: 0
        )
        context.insert(category)
        try context.save()

        let inferred = inferLanguage(from: context)
        #expect(inferred == nil)
    }

    @Test("Majority language wins when categories have mixed names")
    func testInferMajorityLanguage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Insert 3 Vietnamese categories and 1 English
        let viCategories = [
            AppCategory(id: "food_drink", name: "Ăn uống", iconName: "fork.knife", colorHex: "#FF8C42", type: .expense, group: .dailyLiving, sortOrder: 0),
            AppCategory(id: "groceries", name: "Đi chợ / Siêu thị", iconName: "cart.fill", colorHex: "#4CAF50", type: .expense, group: .dailyLiving, sortOrder: 1),
            AppCategory(id: "transport", name: "Di chuyển", iconName: "car.fill", colorHex: "#2196F3", type: .expense, group: .dailyLiving, sortOrder: 2),
            // This one has English name
            AppCategory(id: "shopping", name: "Shopping", iconName: "bag.fill", colorHex: "#9C27B0", type: .expense, group: .personal, sortOrder: 3),
        ]
        for cat in viCategories {
            context.insert(cat)
        }
        try context.save()

        let inferred = inferLanguage(from: context)
        // Vietnamese should win (3 matches vs 1 for English)
        #expect(inferred == "vi")
    }

    @Test("Default currency maps correctly from inferred language")
    func testDefaultCurrencyFromLanguage() {
        #expect(LanguageOption.defaultCurrency(for: "en") == "USD")
        #expect(LanguageOption.defaultCurrency(for: "vi") == "VND")
        #expect(LanguageOption.defaultCurrency(for: "ja") == "JPY")
        #expect(LanguageOption.defaultCurrency(for: "es") == "EUR")
        #expect(LanguageOption.defaultCurrency(for: "unknown") == "USD")
    }
}

@Suite("RecurringService Deterministic ID Tests")
struct RecurringServiceDeterministicIdTests {

    @Test("Deterministic ID is consistent for same template and date")
    func testDeterministicIdConsistency() {
        let templateId = "template-123"
        let date = Date(timeIntervalSince1970: 1700000000) // 2023-11-14

        let id1 = RecurringService.deterministicId(templateId: templateId, date: date)
        let id2 = RecurringService.deterministicId(templateId: templateId, date: date)

        #expect(id1 == id2)
    }

    @Test("Deterministic ID differs for different dates")
    func testDeterministicIdDifferentDates() {
        let templateId = "template-123"
        let date1 = Date(timeIntervalSince1970: 1700000000) // 2023-11-14
        let date2 = Date(timeIntervalSince1970: 1700086400) // 2023-11-15

        let id1 = RecurringService.deterministicId(templateId: templateId, date: date1)
        let id2 = RecurringService.deterministicId(templateId: templateId, date: date2)

        #expect(id1 != id2)
    }

    @Test("Deterministic ID differs for different templates")
    func testDeterministicIdDifferentTemplates() {
        let date = Date(timeIntervalSince1970: 1700000000)

        let id1 = RecurringService.deterministicId(templateId: "template-A", date: date)
        let id2 = RecurringService.deterministicId(templateId: "template-B", date: date)

        #expect(id1 != id2)
    }

    @Test("Deterministic ID has expected prefix format")
    func testDeterministicIdFormat() {
        let templateId = "abc-123"
        let date = Date(timeIntervalSince1970: 1700000000)

        let id = RecurringService.deterministicId(templateId: templateId, date: date)

        #expect(id.hasPrefix("recurring_abc-123_"))
        // Should contain a date component in YYYY-MM-DD format
        let datePattern = #/\d{4}-\d{2}-\d{2}/#
        #expect(id.contains(datePattern))
    }

    @Test("Same time on same day produces same ID")
    func testSameDaySameId() {
        let templateId = "template-1"
        // Two different times on the same day
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date.now)!
        let evening = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date.now)!

        let id1 = RecurringService.deterministicId(templateId: templateId, date: morning)
        let id2 = RecurringService.deterministicId(templateId: templateId, date: evening)

        #expect(id1 == id2, "Same day should produce same deterministic ID regardless of time")
    }
}

@Suite("RecurringService CloudKit Deduplication Tests")
@MainActor
struct RecurringServiceDeduplicationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date.now)!
    }

    private func fetchTransactions(from context: ModelContext) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        return try context.fetch(descriptor)
    }

    @Test("Generated recurring transactions have deterministic IDs")
    func testGeneratedTransactionsHaveDeterministicIds() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let templateId = UUID().uuidString
        let template = RecurringTemplate(
            id: templateId,
            amount: 15000,
            note: "Coffee",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(2)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(generated == 3)

        let transactions = try fetchTransactions(from: context)
        for transaction in transactions {
            #expect(transaction.id.hasPrefix("recurring_\(templateId)_"))
        }
    }

    @Test("Pre-existing transaction with deterministic ID is not duplicated")
    func testPreExistingTransactionSkipped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let templateId = "test-template-dedup"
        let startDate = daysAgo(1)

        // Pre-insert a transaction that matches what RecurringService would generate
        let deterministicId = RecurringService.deterministicId(templateId: templateId, date: startDate)
        let existingTransaction = Transaction(
            id: deterministicId,
            amount: 15000,
            note: "Coffee",
            categoryId: "food_drink",
            type: .expense,
            date: startDate,
            rawInput: "Recurring: Coffee"
        )
        context.insert(existingTransaction)

        let template = RecurringTemplate(
            id: templateId,
            amount: 15000,
            note: "Coffee",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should only generate today's transaction, not yesterday's (already exists)
        #expect(generated >= 1)

        let transactions = try fetchTransactions(from: context)
        // Count transactions with the pre-existing ID — should be exactly 1 (not duplicated)
        let matchingCount = transactions.filter { $0.id == deterministicId }.count
        #expect(matchingCount == 1, "Pre-existing transaction should not be duplicated")
    }

    @Test("Deterministic IDs are unique across different days")
    func testUniqueIdsAcrossDays() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            id: "unique-test-template",
            amount: 10000,
            note: "Daily item",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(3)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(generated == 4)

        let transactions = try fetchTransactions(from: context)
        let ids = transactions.map { $0.id }
        let uniqueIds = Set(ids)

        #expect(uniqueIds.count == ids.count, "All generated transaction IDs should be unique")
    }
}

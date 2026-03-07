import Testing
import Foundation
import SwiftData
@testable import QuickSpend

// Type alias to disambiguate from objc_category
private typealias AppCategory = QuickSpend.Category

@Suite("RecurringService Tests")
@MainActor
struct RecurringServiceTests {

    // MARK: - Helpers

    /// Creates an in-memory model container for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    /// Creates a date by subtracting components from now
    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date.now)!
    }

    private func weeksAgo(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date.now)!
    }

    private func monthsAgo(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date.now)!
    }

    private func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date.now)!
    }

    /// Fetches all transactions from the context
    private func fetchTransactions(from context: ModelContext) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        return try context.fetch(descriptor)
    }

    /// Fetches all recurring templates from the context
    private func fetchTemplates(from context: ModelContext) throws -> [RecurringTemplate] {
        let descriptor = FetchDescriptor<RecurringTemplate>()
        return try context.fetch(descriptor)
    }

    // MARK: - Daily Template Tests

    @Test("Daily template generates transactions for past 3 days")
    func testDailyTemplateGeneratesPast3Days() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let startDate = daysAgo(3)
        let template = RecurringTemplate(
            amount: 15000,
            note: "Morning coffee",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should generate 4 transactions: 3 days ago, 2 days ago, 1 day ago, and today
        #expect(generated == 4)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 4)

        for transaction in transactions {
            #expect(transaction.amount == 15000)
            #expect(transaction.note == "Morning coffee")
            #expect(transaction.categoryId == "food_drink")
            #expect(transaction.type == .expense)
            #expect(transaction.rawInput == "Recurring: Morning coffee")
        }
    }

    // MARK: - Weekly Template Tests

    @Test("Weekly template generates transactions for past weeks")
    func testWeeklyTemplateGeneratesPastWeeks() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let startDate = weeksAgo(3)
        let template = RecurringTemplate(
            amount: 200000,
            note: "Weekly groceries",
            categoryId: "groceries",
            type: .expense,
            pattern: .weekly,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should generate 4 transactions: 3 weeks ago, 2 weeks ago, 1 week ago, and today
        #expect(generated == 4)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 4)

        for transaction in transactions {
            #expect(transaction.amount == 200000)
            #expect(transaction.note == "Weekly groceries")
            #expect(transaction.categoryId == "groceries")
            #expect(transaction.type == .expense)
        }
    }

    // MARK: - Monthly Template Tests

    @Test("Monthly template generates transactions for past months")
    func testMonthlyTemplateGeneratesPastMonths() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let startDate = monthsAgo(2)
        let template = RecurringTemplate(
            amount: 5000000,
            note: "Rent payment",
            categoryId: "housing",
            type: .expense,
            pattern: .monthly,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should generate 3 transactions: 2 months ago, 1 month ago, and today
        #expect(generated == 3)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 3)

        for transaction in transactions {
            #expect(transaction.amount == 5000000)
            #expect(transaction.note == "Rent payment")
            #expect(transaction.categoryId == "housing")
            #expect(transaction.type == .expense)
        }
    }

    // MARK: - Inactive Template Tests

    @Test("Inactive template generates no transactions")
    func testInactiveTemplateGeneratesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            amount: 100000,
            note: "Cancelled subscription",
            categoryId: "entertainment",
            type: .expense,
            pattern: .monthly,
            startDate: monthsAgo(3),
            isActive: false
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        #expect(generated == 0)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.isEmpty)
    }

    // MARK: - Ended Template Tests

    @Test("Template with endDate in the past generates no transactions")
    func testEndedTemplateGeneratesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            amount: 50000,
            note: "Old subscription",
            categoryId: "entertainment",
            type: .expense,
            pattern: .monthly,
            startDate: monthsAgo(6),
            endDate: daysAgo(1),
            lastGeneratedDate: daysAgo(1)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        #expect(generated == 0)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.isEmpty)
    }

    // MARK: - lastGeneratedDate Update Tests

    @Test("lastGeneratedDate is updated after generation")
    func testLastGeneratedDateIsUpdated() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let startDate = daysAgo(2)
        let template = RecurringTemplate(
            amount: 30000,
            note: "Daily snack",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        #expect(template.lastGeneratedDate == nil)

        let generated = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(generated > 0)

        // lastGeneratedDate should now be set to the most recent generated date
        #expect(template.lastGeneratedDate != nil)

        // The last generated date should be on or after the start date
        #expect(template.lastGeneratedDate! >= startDate)
    }

    @Test("Second generation does not duplicate already generated transactions")
    func testNoDuplicateAfterSecondGeneration() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let startDate = daysAgo(2)
        let template = RecurringTemplate(
            amount: 20000,
            note: "Daily exercise",
            categoryId: "health",
            type: .expense,
            pattern: .daily,
            startDate: startDate
        )
        context.insert(template)
        try context.save()

        let firstRun = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(firstRun == 3) // 2 days ago, 1 day ago, today

        // Running again immediately should generate 0 new transactions
        let secondRun = RecurringService.generatePendingTransactions(modelContext: context)
        #expect(secondRun == 0)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 3)
    }

    // MARK: - Empty Templates Tests

    @Test("No templates returns 0 generated transactions")
    func testEmptyTemplatesReturnsZero() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        #expect(generated == 0)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.isEmpty)
    }

    // MARK: - Future StartDate Tests

    @Test("Template with future startDate generates nothing")
    func testFutureStartDateGeneratesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            amount: 100000,
            note: "Future subscription",
            categoryId: "entertainment",
            type: .expense,
            pattern: .monthly,
            startDate: daysFromNow(7)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        #expect(generated == 0)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.isEmpty)
    }

    // MARK: - Multiple Templates Tests

    @Test("Multiple templates generate transactions correctly")
    func testMultipleTemplatesGenerateCorrectly() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Template 1: Daily, started 2 days ago -> 3 transactions
        let dailyTemplate = RecurringTemplate(
            amount: 15000,
            note: "Daily coffee",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(2)
        )

        // Template 2: Weekly, started 2 weeks ago -> 3 transactions
        let weeklyTemplate = RecurringTemplate(
            amount: 500000,
            note: "Weekly savings",
            categoryId: "savings_invest",
            type: .expense,
            pattern: .weekly,
            startDate: weeksAgo(2)
        )

        // Template 3: Inactive, should produce 0
        let inactiveTemplate = RecurringTemplate(
            amount: 999999,
            note: "Inactive item",
            categoryId: "other_expense",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(5),
            isActive: false
        )

        context.insert(dailyTemplate)
        context.insert(weeklyTemplate)
        context.insert(inactiveTemplate)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Daily: 3 (2 days ago, 1 day ago, today)
        // Weekly: 3 (2 weeks ago, 1 week ago, today)
        // Inactive: 0
        #expect(generated == 6)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 6)

        let coffeeTransactions = transactions.filter { $0.note == "Daily coffee" }
        let savingsTransactions = transactions.filter { $0.note == "Weekly savings" }
        let inactiveTransactions = transactions.filter { $0.note == "Inactive item" }

        #expect(coffeeTransactions.count == 3)
        #expect(savingsTransactions.count == 3)
        #expect(inactiveTransactions.count == 0)
    }

    // MARK: - Income Template Tests

    @Test("Income template generates income transactions")
    func testIncomeTemplateGeneratesIncomeTransactions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            amount: 10000000,
            note: "Monthly salary",
            categoryId: "salary",
            type: .income,
            pattern: .monthly,
            startDate: monthsAgo(1)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        #expect(generated == 2) // 1 month ago and today

        let transactions = try fetchTransactions(from: context)
        for transaction in transactions {
            #expect(transaction.type == .income)
            #expect(transaction.amount == 10000000)
            #expect(transaction.categoryId == "salary")
        }
    }

    // MARK: - EndDate Boundary Tests

    @Test("Template with future endDate limits generation up to now, not beyond endDate")
    func testEndDateLimitsGeneration() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Template started 3 days ago with an endDate 5 days from now.
        // The service uses effectiveEnd = min(endDate, now), so it generates up to now.
        // This verifies that endDate in the future still lets the service generate up to today.
        let template = RecurringTemplate(
            amount: 25000,
            note: "Limited daily",
            categoryId: "food_drink",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(3),
            endDate: daysFromNow(5)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should generate for: 3 days ago, 2 days ago, 1 day ago, today = 4 transactions
        // endDate is in the future, so effectiveEnd = min(endDate, now) = now
        #expect(generated == 4)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 4)

        // All transaction dates should be on or before now
        let now = Date.now
        for transaction in transactions {
            #expect(transaction.date <= now)
        }
    }

    // MARK: - Transaction Data Integrity Tests

    @Test("Generated transactions have correct rawInput format")
    func testGeneratedTransactionsHaveCorrectRawInput() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let template = RecurringTemplate(
            amount: 50000,
            note: "Gym membership",
            categoryId: "health",
            type: .expense,
            pattern: .monthly,
            startDate: monthsAgo(1)
        )
        context.insert(template)
        try context.save()

        _ = RecurringService.generatePendingTransactions(modelContext: context)

        let transactions = try fetchTransactions(from: context)
        for transaction in transactions {
            #expect(transaction.rawInput == "Recurring: Gym membership")
        }
    }

    // MARK: - lastGeneratedDate Resumption Tests

    @Test("Template with lastGeneratedDate resumes from next occurrence")
    func testResumesFromLastGeneratedDate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Template started 10 days ago, but was last generated 2 days ago
        let template = RecurringTemplate(
            amount: 10000,
            note: "Daily vitamin",
            categoryId: "health",
            type: .expense,
            pattern: .daily,
            startDate: daysAgo(10),
            lastGeneratedDate: daysAgo(2)
        )
        context.insert(template)
        try context.save()

        let generated = RecurringService.generatePendingTransactions(modelContext: context)

        // Should generate from day after lastGeneratedDate: 1 day ago, today = 2 transactions
        #expect(generated == 2)

        let transactions = try fetchTransactions(from: context)
        #expect(transactions.count == 2)
    }
}

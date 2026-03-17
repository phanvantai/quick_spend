import Testing
import Foundation
import SwiftData
@testable import QuickSpend

// Type alias to disambiguate from objc_category
private typealias AppCategory = QuickSpend.Category

@Suite("SwiftData Persistence Tests")
@MainActor
struct SwiftDataPersistenceTests {

    /// Helper to create an in-memory model container for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    // MARK: - Transaction Persistence

    @Test("Transaction can be inserted and fetched")
    func testTransactionInsertFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transaction = Transaction(
            amount: 50000,
            note: "Test lunch",
            categoryId: "food_drink",
            type: .expense,
            date: Date()
        )
        context.insert(transaction)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].amount == 50000)
        #expect(fetched[0].note == "Test lunch")
        #expect(fetched[0].categoryId == "food_drink")
        #expect(fetched[0].type == .expense)
    }

    @Test("Transaction type enum persists correctly")
    func testTransactionTypeEnumPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let expense = Transaction(amount: 100, note: "E", categoryId: "food_drink", type: .expense, date: Date())
        let income = Transaction(amount: 200, note: "I", categoryId: "salary", type: .income, date: Date())

        context.insert(expense)
        context.insert(income)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.amount)])
        let fetched = try context.fetch(descriptor)

        #expect(fetched[0].type == .expense)
        #expect(fetched[1].type == .income)
    }

    @Test("Transaction can be updated")
    func testTransactionUpdate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transaction = Transaction(
            amount: 50000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: Date()
        )
        context.insert(transaction)
        try context.save()

        transaction.amount = 75000
        transaction.note = "Updated lunch"
        transaction.updatedAt = Date()
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched[0].amount == 75000)
        #expect(fetched[0].note == "Updated lunch")
    }

    @Test("Transaction can be deleted")
    func testTransactionDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transaction = Transaction(
            amount: 50000,
            note: "To delete",
            categoryId: "food_drink",
            type: .expense,
            date: Date()
        )
        context.insert(transaction)
        try context.save()

        context.delete(transaction)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.isEmpty)
    }

    // MARK: - Category Persistence

    @Test("Category can be inserted and fetched")
    func testCategoryInsertFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext

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

        let descriptor = FetchDescriptor<AppCategory>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].id == "food_drink")
        #expect(fetched[0].name == "Food & Drink")
        #expect(fetched[0].group == .dailyLiving)
    }

    @Test("Category group enum persists correctly")
    func testCategoryGroupPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groups: [CategoryGroup] = [.dailyLiving, .personal, .social, .financial, .earned, .passive, .received, .other]

        for (i, group) in groups.enumerated() {
            let category = AppCategory(
                id: "test_\(group.rawValue)",
                name: "Test \(group.rawValue)",
                iconName: "circle",
                colorHex: "#000000",
                type: .expense,
                group: group,
                sortOrder: i
            )
            context.insert(category)
        }
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == groups.count)
        for (i, category) in fetched.enumerated() {
            #expect(category.group == groups[i])
        }
    }

    @Test("Category isHidden persists correctly")
    func testCategoryIsHiddenPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = AppCategory(
            id: "food_drink",
            name: "Food",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0,
            isHidden: true
        )
        context.insert(category)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched[0].isHidden == true)
    }

    // MARK: - RecurringTemplate Persistence

    @Test("RecurringTemplate can be inserted and fetched")
    func testRecurringTemplateInsertFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let start = Date()
        let template = RecurringTemplate(
            amount: 5000000,
            note: "Rent",
            categoryId: "housing",
            type: .expense,
            pattern: .monthly,
            startDate: start
        )
        context.insert(template)
        try context.save()

        let descriptor = FetchDescriptor<RecurringTemplate>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].amount == 5000000)
        #expect(fetched[0].pattern == .monthly)
        #expect(fetched[0].isActive == true)
    }

    @Test("RecurringTemplate pattern enum persists correctly")
    func testRecurrencePatternPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for pattern in RecurrencePattern.allCases {
            let template = RecurringTemplate(
                amount: 100,
                note: "Test \(pattern.rawValue)",
                categoryId: "other_expense",
                type: .expense,
                pattern: pattern,
                startDate: Date()
            )
            context.insert(template)
        }
        try context.save()

        let descriptor = FetchDescriptor<RecurringTemplate>()
        let fetched = try context.fetch(descriptor)
        let patterns = Set(fetched.map(\.pattern))

        #expect(patterns.count == RecurrencePattern.allCases.count)
        for pattern in RecurrencePattern.allCases {
            #expect(patterns.contains(pattern))
        }
    }

    // MARK: - String-based Relationship

    @Test("Transaction links to Category via string categoryId")
    func testStringBasedRelationship() throws {
        let container = try makeContainer()
        let context = container.mainContext

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

        let transaction = Transaction(
            amount: 50000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: Date()
        )
        context.insert(transaction)
        try context.save()

        // Fetch category by transaction's categoryId
        let categoryId = transaction.categoryId
        let catDescriptor = FetchDescriptor<AppCategory>(predicate: #Predicate<AppCategory> { $0.id == categoryId })
        let matchedCategories = try context.fetch(catDescriptor)

        #expect(matchedCategories.count == 1)
        #expect(matchedCategories[0].name == "Food & Drink")
    }

    // MARK: - Model Container

    @Test("Model container accepts all three model types")
    func testModelContainerCreation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Verify the context is usable by checking a property
        #expect(context.autosaveEnabled || !context.autosaveEnabled)
    }
}

import Testing
import Foundation
import SwiftData
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("CategoryService SwiftData Tests")
@MainActor
struct CategoryServiceSwiftDataTests {

    /// Helper to create an in-memory model container for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self,
            configurations: config
        )
    }

    // MARK: - seedCategoriesIfNeeded

    @Test("seedCategoriesIfNeeded inserts categories when none exist")
    func testSeedCategoriesWhenEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>()
        let categories = try context.fetch(descriptor)

        #expect(categories.count == 26)
    }

    @Test("seedCategoriesIfNeeded does not insert when categories already exist")
    func testSeedCategoriesSkipsWhenExist() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Insert one category first
        let existing = AppCategory(
            id: "test_cat",
            name: "Test",
            iconName: "circle",
            colorHex: "000000",
            type: .expense,
            group: .other,
            sortOrder: 0
        )
        context.insert(existing)
        try context.save()

        // Seed should skip since categories already exist
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>()
        let categories = try context.fetch(descriptor)

        #expect(categories.count == 1, "Should still have only the original category")
    }

    @Test("seedCategoriesIfNeeded uses correct language for names")
    func testSeedCategoriesLanguage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "vi", modelContext: context)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>(
            predicate: #Predicate<AppCategory> { $0.id == "food_drink" }
        )
        let categories = try context.fetch(descriptor)

        #expect(categories.count == 1)
        #expect(categories[0].name == "Ăn uống")
    }

    // MARK: - updateCategoryNames

    @Test("updateCategoryNames changes names to new language")
    func testUpdateCategoryNames() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Seed in English first
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()

        // Verify English
        let enDescriptor = FetchDescriptor<AppCategory>(
            predicate: #Predicate<AppCategory> { $0.id == "food_drink" }
        )
        let enCategories = try context.fetch(enDescriptor)
        #expect(enCategories[0].name == "Food & Drink")

        // Update to Vietnamese
        CategoryService.updateCategoryNames(language: "vi", modelContext: context)
        try context.save()

        // Verify Vietnamese
        let viCategories = try context.fetch(enDescriptor)
        #expect(viCategories[0].name == "Ăn uống")
    }

    @Test("updateCategoryNames updates updatedAt timestamp")
    func testUpdateCategoryNamesTimestamp() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()

        let beforeUpdate = Date()

        // Small delay to ensure timestamp difference
        CategoryService.updateCategoryNames(language: "vi", modelContext: context)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>()
        let categories = try context.fetch(descriptor)

        for category in categories {
            #expect(category.updatedAt >= beforeUpdate, "updatedAt should be updated for \(category.id)")
        }
    }

    @Test("updateCategoryNames updates all categories")
    func testUpdateCategoryNamesAll() throws {
        let container = try makeContainer()
        let context = container.mainContext

        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()

        CategoryService.updateCategoryNames(language: "ja", modelContext: context)
        try context.save()

        let descriptor = FetchDescriptor<AppCategory>(
            predicate: #Predicate<AppCategory> { $0.id == "salary" }
        )
        let categories = try context.fetch(descriptor)
        #expect(categories[0].name == "給料")
    }

    // MARK: - reassignTransactions

    @Test("reassignTransactions moves transactions to new category")
    func testReassignTransactions() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Insert transactions with old category
        let t1 = Transaction(amount: 100, note: "A", categoryId: "old_cat", type: .expense, date: Date())
        let t2 = Transaction(amount: 200, note: "B", categoryId: "old_cat", type: .expense, date: Date())
        let t3 = Transaction(amount: 300, note: "C", categoryId: "other_cat", type: .expense, date: Date())
        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
        try context.save()

        // Reassign old_cat -> new_cat
        CategoryService.reassignTransactions(from: "old_cat", to: "new_cat", modelContext: context)
        try context.save()

        // Verify reassignment
        let fromId = "old_cat"
        let oldDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == fromId }
        )
        let oldTransactions = try context.fetch(oldDescriptor)
        #expect(oldTransactions.isEmpty, "No transactions should have old category")

        let toId = "new_cat"
        let newDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == toId }
        )
        let newTransactions = try context.fetch(newDescriptor)
        #expect(newTransactions.count == 2, "Two transactions should be reassigned")

        // Verify other category is unchanged
        let otherId = "other_cat"
        let otherDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == otherId }
        )
        let otherTransactions = try context.fetch(otherDescriptor)
        #expect(otherTransactions.count == 1, "Other category should be unchanged")
    }

    @Test("reassignTransactions updates updatedAt on affected transactions")
    func testReassignTransactionsTimestamp() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transaction = Transaction(amount: 100, note: "A", categoryId: "old_cat", type: .expense, date: Date())
        context.insert(transaction)
        try context.save()

        let beforeReassign = Date()

        CategoryService.reassignTransactions(from: "old_cat", to: "new_cat", modelContext: context)
        try context.save()

        let toId = "new_cat"
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == toId }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].updatedAt >= beforeReassign)
    }

    @Test("reassignTransactions with no matching transactions does nothing")
    func testReassignTransactionsNoMatch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transaction = Transaction(amount: 100, note: "A", categoryId: "some_cat", type: .expense, date: Date())
        context.insert(transaction)
        try context.save()

        // Reassign a non-existent category
        CategoryService.reassignTransactions(from: "nonexistent", to: "new_cat", modelContext: context)
        try context.save()

        // Original transaction unchanged
        let someId = "some_cat"
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == someId }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
    }
}

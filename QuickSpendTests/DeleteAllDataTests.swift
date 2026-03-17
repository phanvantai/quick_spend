import Testing
import SwiftData
@testable import QuickSpend

@Suite("Delete All Data Tests")
struct DeleteAllDataTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self,
            configurations: config
        )
    }

    private func makeTransaction(index: Int) -> Transaction {
        Transaction(amount: Double(index + 1) * 10, note: "Test \(index)", categoryId: "cat_\(index)")
    }

    private func makeCategory(index: Int) -> Category {
        Category(id: "cat_\(index)", name: "Cat \(index)", iconName: "star", colorHex: "#FF0000", type: .expense)
    }

    private func makeTemplate(index: Int) -> RecurringTemplate {
        RecurringTemplate(amount: Double(index + 1) * 100, note: "Recurring \(index)", categoryId: "cat_\(index)")
    }

    @Test("Delete all transactions removes every record")
    func testDeleteAllTransactions() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        for i in 0..<5 {
            context.insert(makeTransaction(index: i))
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 5)

        try context.delete(model: Transaction.self)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test("Delete all categories removes every record")
    func testDeleteAllCategories() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        for i in 0..<3 {
            context.insert(makeCategory(index: i))
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 3)

        try context.delete(model: Category.self)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 0)
    }

    @Test("Delete all recurring templates removes every record")
    func testDeleteAllRecurringTemplates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        for i in 0..<2 {
            context.insert(makeTemplate(index: i))
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<RecurringTemplate>()) == 2)

        try context.delete(model: RecurringTemplate.self)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<RecurringTemplate>()) == 0)
    }

    @Test("Delete all data clears all model types at once")
    func testDeleteAllDataClearsEverything() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        context.insert(makeTransaction(index: 0))
        context.insert(makeCategory(index: 0))
        context.insert(makeTemplate(index: 0))
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<RecurringTemplate>()) == 1)

        try context.delete(model: Transaction.self)
        try context.delete(model: Category.self)
        try context.delete(model: RecurringTemplate.self)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Category>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RecurringTemplate>()) == 0)
    }
}

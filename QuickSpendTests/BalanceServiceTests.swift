import Testing
import Foundation
import SwiftData
@testable import QuickSpend

@Suite("BalanceService Tests")
@MainActor
struct BalanceServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
            configurations: config
        )
    }

    private func insertAnchor(
        openingBalance: Double,
        anchorDate: Date,
        in context: ModelContext
    ) throws {
        let anchor = BalanceAnchor(openingBalance: openingBalance, anchorDate: anchorDate)
        context.insert(anchor)
        try context.save()
    }

    // MARK: - Test 1: Empty state

    @Test("Empty state — balance equals openingBalance when no transactions exist")
    func testEmptyStateBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 1_000_000)
    }

    // MARK: - Test 2: Income adds to balance

    @Test("Income transaction — balance = opening + income amount")
    func testIncomeAddsToBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 500_000, anchorDate: anchorDate, in: context)

        let income = Transaction(
            amount: 200_000,
            note: "Salary",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(3600) // 1 hour after anchor
        )
        context.insert(income)
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 700_000)
    }

    // MARK: - Test 3: Expense subtracts from balance

    @Test("Expense transaction — balance = opening − expense amount")
    func testExpenseSubtractsFromBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 500_000, anchorDate: anchorDate, in: context)

        let expense = Transaction(
            amount: 75_000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: anchorDate.addingTimeInterval(3600)
        )
        context.insert(expense)
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 425_000)
    }

    // MARK: - Test 4: Multi-transaction sum (10 mixed)

    @Test("Multi-transaction — balance correctly sums 10 mixed income/expense entries")
    func testMultiTransactionSum() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        // 5 incomes totaling 500_000, 5 expenses totaling 300_000 → net +200_000
        let incomes: [Double] = [100_000, 100_000, 100_000, 100_000, 100_000]
        let expenses: [Double] = [50_000, 60_000, 70_000, 60_000, 60_000]

        for (i, amount) in incomes.enumerated() {
            let tx = Transaction(
                amount: amount,
                note: "Income \(i)",
                categoryId: "salary",
                type: .income,
                date: anchorDate.addingTimeInterval(Double(i + 1) * 3600)
            )
            context.insert(tx)
        }
        for (i, amount) in expenses.enumerated() {
            let tx = Transaction(
                amount: amount,
                note: "Expense \(i)",
                categoryId: "food_drink",
                type: .expense,
                date: anchorDate.addingTimeInterval(Double(i + 100) * 3600)
            )
            context.insert(tx)
        }
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 1_200_000)
    }

    // MARK: - Test 5: Anchor date >= boundary inclusive

    @Test("Anchor date boundary — transactions before anchor excluded, on/after included")
    func testAnchorDateBoundaryInclusive() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        // Transaction BEFORE anchor — must be excluded
        let before = Transaction(
            amount: 999_999,
            note: "Before anchor",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(-1) // 1 second before
        )
        context.insert(before)

        // Transaction EXACTLY ON anchor — must be included (>= boundary)
        let onBoundary = Transaction(
            amount: 100_000,
            note: "On anchor",
            categoryId: "salary",
            type: .income,
            date: anchorDate // exactly at anchor
        )
        context.insert(onBoundary)

        // Transaction AFTER anchor — must be included
        let after = Transaction(
            amount: 50_000,
            note: "After anchor",
            categoryId: "food_drink",
            type: .expense,
            date: anchorDate.addingTimeInterval(7200)
        )
        context.insert(after)

        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        // 1_000_000 opening + 100_000 (on) − 50_000 (after) = 1_050_000
        // 999_999 (before) excluded
        #expect(balance == 1_050_000)
    }
}

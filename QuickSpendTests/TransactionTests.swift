import Testing
import Foundation
@testable import QuickSpend

@Suite("Transaction Model Tests")
struct TransactionTests {

    @Test("Transaction initializes with correct defaults")
    func testInitialization() {
        let now = Date()
        let transaction = Transaction(
            amount: 50000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: now
        )

        #expect(transaction.amount == 50000)
        #expect(transaction.note == "Lunch")
        #expect(transaction.categoryId == "food_drink")
        #expect(transaction.type == .expense)
        #expect(transaction.date == now)
        #expect(transaction.rawInput == nil)
        #expect(transaction.confidence == nil)
        #expect(!transaction.id.isEmpty)
    }

    @Test("isIncome returns true for income type")
    func testIsIncome() {
        let transaction = Transaction(
            amount: 5000000,
            note: "Salary",
            categoryId: "salary",
            type: .income,
            date: Date()
        )

        #expect(transaction.isIncome == true)
        #expect(transaction.isExpense == false)
    }

    @Test("isExpense returns true for expense type")
    func testIsExpense() {
        let transaction = Transaction(
            amount: 35000,
            note: "Coffee",
            categoryId: "food_drink",
            type: .expense,
            date: Date()
        )

        #expect(transaction.isExpense == true)
        #expect(transaction.isIncome == false)
    }

    @Test("Transaction stores optional AI fields")
    func testAIFields() {
        let transaction = Transaction(
            amount: 100000,
            note: "Groceries",
            categoryId: "groceries",
            type: .expense,
            date: Date(),
            rawInput: "I spent 100k on groceries",
            confidence: 0.95
        )

        #expect(transaction.rawInput == "I spent 100k on groceries")
        #expect(transaction.confidence == 0.95)
    }

    @Test("Transaction generates unique IDs")
    func testUniqueIds() {
        let t1 = Transaction(amount: 100, note: "A", categoryId: "food_drink", type: .expense, date: Date())
        let t2 = Transaction(amount: 200, note: "B", categoryId: "transport", type: .expense, date: Date())

        #expect(t1.id != t2.id)
    }
}

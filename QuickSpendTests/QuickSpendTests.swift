import Testing
import Foundation
@testable import QuickSpend

/// Integration-level sanity tests for the QuickSpend module
@Suite("QuickSpend Integration Tests")
struct QuickSpendTests {

    @Test("ParsedTransaction has unique IDs")
    func testParsedTransactionUniqueIds() {
        let t1 = ParsedTransaction(amount: 100, note: "test", categoryId: "food_drink", type: .expense, date: .now, confidence: 0.9)
        let t2 = ParsedTransaction(amount: 200, note: "test2", categoryId: "transport", type: .expense, date: .now, confidence: 0.85)

        #expect(t1.id != t2.id)
    }

    @Test("ParsedTransaction stores values correctly")
    func testParsedTransactionValues() {
        let date = Date.now
        let t = ParsedTransaction(amount: 50000, note: "coffee", categoryId: "food_drink", type: .expense, date: date, confidence: 0.95)

        #expect(t.amount == 50000)
        #expect(t.note == "coffee")
        #expect(t.categoryId == "food_drink")
        #expect(t.type == .expense)
        #expect(t.confidence == 0.95)
    }

    @Test("MonthlyTrend stores values correctly")
    func testMonthlyTrendValues() {
        let date = Date.now
        let trend = MonthlyTrend(month: date, monthLabel: "Jan", totalExpenses: 500000, totalIncome: 1000000)

        #expect(trend.monthLabel == "Jan")
        #expect(trend.totalExpenses == 500000)
        #expect(trend.totalIncome == 1000000)
        #expect(trend.month == date)
    }

    @Test("CategoryStats stores values correctly")
    func testCategoryStatsValues() {
        let stats = CategoryStats(
            categoryId: "food_drink",
            categoryName: "Food & Drink",
            totalAmount: 500000,
            count: 10,
            percentage: 45.5,
            colorHex: "#FF8C42",
            iconName: "fork.knife",
            type: .expense
        )

        #expect(stats.categoryId == "food_drink")
        #expect(stats.categoryName == "Food & Drink")
        #expect(stats.totalAmount == 500000)
        #expect(stats.count == 10)
        #expect(stats.percentage == 45.5)
        #expect(stats.colorHex == "#FF8C42")
        #expect(stats.iconName == "fork.knife")
        #expect(stats.type == .expense)
    }

    @Test("Full workflow: create transactions and calculate stats")
    func testFullStatsWorkflow() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: today)!

        let transactions = [
            Transaction(amount: 50000, note: "Lunch", categoryId: "food_drink", type: .expense, date: today),
            Transaction(amount: 30000, note: "Coffee", categoryId: "food_drink", type: .expense, date: today),
            Transaction(amount: 100000, note: "Gas", categoryId: "transport", type: .expense, date: today),
            Transaction(amount: 15000000, note: "Salary", categoryId: "salary", type: .income, date: today),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: today)

        #expect(stats.transactionCount == 4)
        #expect(stats.totalExpenses == 180000)
        #expect(stats.totalIncome == 15000000)
        #expect(stats.netBalance == 15000000 - 180000)
        #expect(stats.categoryTotals["food_drink"] == 80000)
        #expect(stats.categoryTotals["transport"] == 100000)
        #expect(stats.categoryTotals["salary"] == 15000000)
    }

    @Test("Full workflow: parse response and validate")
    func testFullParseWorkflow() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "description": "coffee", "category": "food_drink", "type": "expense", "date": "today", "confidence": 0.95] as [String: Any],
                ["amount": 15000000, "description": "salary", "category": "salary", "type": "income", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")

        #expect(results.count == 2)
        #expect(results[0].type == .expense)
        #expect(results[0].categoryId == "food_drink")
        #expect(results[1].type == .income)
        #expect(results[1].categoryId == "salary")
    }
}

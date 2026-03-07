import Testing
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("PeriodStats Tests")
struct PeriodStatsTests {

    // MARK: - Helpers

    private func makeTransaction(
        amount: Double,
        type: TransactionType = .expense,
        categoryId: String = "food_drink",
        date: Date = .now
    ) -> Transaction {
        Transaction(
            amount: amount,
            note: "Test",
            categoryId: categoryId,
            type: type,
            date: date
        )
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: .now)!
    }

    private var endDate: Date {
        Date.now
    }

    // MARK: - Empty Stats

    @Test("Empty stats returns all zeros")
    func testEmptyStats() {
        let stats = PeriodStats.empty(startDate: startDate, endDate: endDate)

        #expect(stats.totalAmount == 0)
        #expect(stats.totalIncome == 0)
        #expect(stats.totalExpenses == 0)
        #expect(stats.netBalance == 0)
        #expect(stats.savingsRate == 0)
        #expect(stats.transactionCount == 0)
        #expect(stats.incomeCount == 0)
        #expect(stats.expenseCount == 0)
        #expect(stats.averagePerDay == 0)
        #expect(stats.averagePerTransaction == 0)
        #expect(stats.highestExpense == nil)
        #expect(stats.lowestExpense == nil)
        #expect(stats.highestIncome == nil)
        #expect(stats.lowestIncome == nil)
        #expect(stats.categoryBreakdown.isEmpty)
        #expect(stats.dailySpending.isEmpty)
        #expect(stats.dailyIncome.isEmpty)
        #expect(stats.dailyNet.isEmpty)
        #expect(stats.categoryTotals.isEmpty)
        #expect(stats.categoryCounts.isEmpty)
    }

    // MARK: - fromTransactions

    @Test("fromTransactions returns empty for no transactions")
    func testFromTransactionsEmpty() {
        let stats = PeriodStats.fromTransactions([], startDate: startDate, endDate: endDate)
        #expect(stats.transactionCount == 0)
        #expect(stats.totalAmount == 0)
    }

    @Test("fromTransactions calculates expense totals correctly")
    func testExpenseTotals() {
        let transactions = [
            makeTransaction(amount: 100),
            makeTransaction(amount: 200),
            makeTransaction(amount: 300),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.totalExpenses == 600)
        #expect(stats.totalIncome == 0)
        #expect(stats.totalAmount == 600)
        #expect(stats.netBalance == -600)
        #expect(stats.transactionCount == 3)
        #expect(stats.expenseCount == 3)
        #expect(stats.incomeCount == 0)
    }

    @Test("fromTransactions calculates income totals correctly")
    func testIncomeTotals() {
        let transactions = [
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
            makeTransaction(amount: 500, type: .income, categoryId: "freelance"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.totalIncome == 1500)
        #expect(stats.totalExpenses == 0)
        #expect(stats.totalAmount == 1500)
        #expect(stats.netBalance == 1500)
        #expect(stats.incomeCount == 2)
        #expect(stats.expenseCount == 0)
    }

    @Test("fromTransactions calculates mixed income and expense correctly")
    func testMixedStats() {
        let transactions = [
            makeTransaction(amount: 200, type: .expense),
            makeTransaction(amount: 300, type: .expense),
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.totalExpenses == 500)
        #expect(stats.totalIncome == 1000)
        #expect(stats.totalAmount == 1500)
        #expect(stats.netBalance == 500)
        #expect(stats.transactionCount == 3)
    }

    @Test("fromTransactions calculates savings rate correctly")
    func testSavingsRate() {
        let transactions = [
            makeTransaction(amount: 200, type: .expense),
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        // savingsRate = (netBalance / totalIncome) * 100 = (800 / 1000) * 100 = 80
        #expect(stats.savingsRate == 80.0)
    }

    @Test("fromTransactions savings rate is zero when no income")
    func testSavingsRateNoIncome() {
        let transactions = [
            makeTransaction(amount: 200, type: .expense),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)
        #expect(stats.savingsRate == 0.0)
    }

    @Test("fromTransactions identifies highest and lowest expenses")
    func testHighestLowestExpenses() {
        let transactions = [
            makeTransaction(amount: 100),
            makeTransaction(amount: 500),
            makeTransaction(amount: 50),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.highestExpense?.amount == 500)
        #expect(stats.lowestExpense?.amount == 50)
    }

    @Test("fromTransactions identifies highest and lowest income")
    func testHighestLowestIncome() {
        let transactions = [
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
            makeTransaction(amount: 5000, type: .income, categoryId: "bonus"),
            makeTransaction(amount: 200, type: .income, categoryId: "freelance"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.highestIncome?.amount == 5000)
        #expect(stats.lowestIncome?.amount == 200)
    }

    @Test("fromTransactions calculates category totals correctly")
    func testCategoryTotals() {
        let transactions = [
            makeTransaction(amount: 100, categoryId: "food_drink"),
            makeTransaction(amount: 200, categoryId: "food_drink"),
            makeTransaction(amount: 300, categoryId: "transport"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.categoryTotals["food_drink"] == 300)
        #expect(stats.categoryTotals["transport"] == 300)
        #expect(stats.categoryCounts["food_drink"] == 2)
        #expect(stats.categoryCounts["transport"] == 1)
    }

    @Test("fromTransactions calculates daily spending correctly")
    func testDailySpending() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let transactions = [
            makeTransaction(amount: 100, date: today),
            makeTransaction(amount: 200, date: today),
            makeTransaction(amount: 300, date: yesterday),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: yesterday, endDate: today)

        #expect(stats.dailySpending[today] == 300)
        #expect(stats.dailySpending[yesterday] == 300)
    }

    @Test("fromTransactions calculates daily net correctly")
    func testDailyNet() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let transactions = [
            makeTransaction(amount: 200, type: .expense, date: today),
            makeTransaction(amount: 1000, type: .income, categoryId: "salary", date: today),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: today, endDate: today)

        #expect(stats.dailyNet[today] == 800)  // 1000 income - 200 expense
    }

    @Test("fromTransactions calculates averagePerTransaction correctly")
    func testAveragePerTransaction() {
        let transactions = [
            makeTransaction(amount: 100),
            makeTransaction(amount: 200),
            makeTransaction(amount: 300, type: .income, categoryId: "salary"),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        // averagePerTransaction = totalAmount / count = 600 / 3 = 200
        #expect(stats.averagePerTransaction == 200.0)
    }

    // MARK: - withCategoryBreakdown

    @Test("withCategoryBreakdown creates proper breakdown")
    func testWithCategoryBreakdown() {
        let transactions = [
            makeTransaction(amount: 100, categoryId: "food_drink"),
            makeTransaction(amount: 200, categoryId: "transport"),
        ]

        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
            AppCategory(id: "transport", name: "Transport", iconName: "car.fill", colorHex: "#0000FF", type: .expense, sortOrder: 1),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)
        let withBreakdown = stats.withCategoryBreakdown(categories: categories)

        #expect(withBreakdown.categoryBreakdown.count == 2)
        // Sorted by totalAmount descending
        #expect(withBreakdown.categoryBreakdown[0].categoryId == "transport")
        #expect(withBreakdown.categoryBreakdown[0].totalAmount == 200)
        #expect(withBreakdown.categoryBreakdown[1].categoryId == "food_drink")
        #expect(withBreakdown.categoryBreakdown[1].totalAmount == 100)
    }

    @Test("withCategoryBreakdown calculates percentages correctly")
    func testBreakdownPercentages() {
        let transactions = [
            makeTransaction(amount: 300, categoryId: "food_drink"),
            makeTransaction(amount: 700, categoryId: "transport"),
        ]

        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
            AppCategory(id: "transport", name: "Transport", iconName: "car.fill", colorHex: "#0000FF", type: .expense, sortOrder: 1),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)
        let withBreakdown = stats.withCategoryBreakdown(categories: categories)

        let transportBreakdown = withBreakdown.categoryBreakdown.first { $0.categoryId == "transport" }
        let foodBreakdown = withBreakdown.categoryBreakdown.first { $0.categoryId == "food_drink" }

        #expect(transportBreakdown?.percentage == 70.0)
        #expect(foodBreakdown?.percentage == 30.0)
    }

    // MARK: - Filtered breakdowns

    @Test("incomeCategoryBreakdown filters correctly")
    func testIncomeCategoryBreakdown() {
        let transactions = [
            makeTransaction(amount: 100, categoryId: "food_drink"),
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
        ]

        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
            AppCategory(id: "salary", name: "Salary", iconName: "wallet.bifold.fill", colorHex: "#00FF00", type: .income, sortOrder: 0),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)
        let withBreakdown = stats.withCategoryBreakdown(categories: categories)

        #expect(withBreakdown.incomeCategoryBreakdown.count == 1)
        #expect(withBreakdown.incomeCategoryBreakdown[0].categoryId == "salary")
    }

    @Test("expenseCategoryBreakdown filters correctly")
    func testExpenseCategoryBreakdown() {
        let transactions = [
            makeTransaction(amount: 100, categoryId: "food_drink"),
            makeTransaction(amount: 1000, type: .income, categoryId: "salary"),
        ]

        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
            AppCategory(id: "salary", name: "Salary", iconName: "wallet.bifold.fill", colorHex: "#00FF00", type: .income, sortOrder: 0),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)
        let withBreakdown = stats.withCategoryBreakdown(categories: categories)

        #expect(withBreakdown.expenseCategoryBreakdown.count == 1)
        #expect(withBreakdown.expenseCategoryBreakdown[0].categoryId == "food_drink")
    }

    @Test("Single transaction stats are correct")
    func testSingleTransaction() {
        let transactions = [
            makeTransaction(amount: 500),
        ]

        let stats = PeriodStats.fromTransactions(transactions, startDate: startDate, endDate: endDate)

        #expect(stats.totalExpenses == 500)
        #expect(stats.transactionCount == 1)
        #expect(stats.highestExpense?.amount == 500)
        #expect(stats.lowestExpense?.amount == 500)
    }
}

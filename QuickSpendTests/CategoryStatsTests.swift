import Testing
import Foundation
@testable import QuickSpend

@Suite("CategoryStats Tests")
struct CategoryStatsTests {

    // MARK: - Helpers

    private func makeStats(
        categoryId: String = "food_drink",
        categoryName: String = "Food & Drink",
        totalAmount: Double = 500.0,
        count: Int = 10,
        percentage: Double = 25.0,
        colorHex: String = "#FF5733",
        iconName: String = "fork.knife",
        type: TransactionType = .expense
    ) -> CategoryStats {
        CategoryStats(
            categoryId: categoryId,
            categoryName: categoryName,
            totalAmount: totalAmount,
            count: count,
            percentage: percentage,
            colorHex: colorHex,
            iconName: iconName,
            type: type
        )
    }

    // MARK: - Initialization

    @Test("CategoryStats initializes with correct values")
    func testInitialization() {
        let stats = makeStats()

        #expect(stats.categoryId == "food_drink")
        #expect(stats.categoryName == "Food & Drink")
        #expect(stats.totalAmount == 500.0)
        #expect(stats.count == 10)
        #expect(stats.percentage == 25.0)
        #expect(stats.colorHex == "#FF5733")
        #expect(stats.iconName == "fork.knife")
        #expect(stats.type == .expense)
    }

    // MARK: - Identifiable

    @Test("id equals categoryId")
    func testIdEqualsCategoryId() {
        let stats = makeStats(categoryId: "transport")
        #expect(stats.id == "transport")
        #expect(stats.id == stats.categoryId)
    }

    @Test("Different categoryIds produce different ids")
    func testDifferentIds() {
        let stats1 = makeStats(categoryId: "food_drink")
        let stats2 = makeStats(categoryId: "transport")
        #expect(stats1.id != stats2.id)
    }

    // MARK: - isIncomeCategory / isExpenseCategory

    @Test("isIncomeCategory returns true for income type")
    func testIsIncomeCategoryTrue() {
        let stats = makeStats(type: .income)
        #expect(stats.isIncomeCategory == true)
        #expect(stats.isExpenseCategory == false)
    }

    @Test("isExpenseCategory returns true for expense type")
    func testIsExpenseCategoryTrue() {
        let stats = makeStats(type: .expense)
        #expect(stats.isExpenseCategory == true)
        #expect(stats.isIncomeCategory == false)
    }

    @Test("isIncomeCategory and isExpenseCategory are mutually exclusive")
    func testMutuallyExclusive() {
        let expenseStats = makeStats(type: .expense)
        #expect(expenseStats.isExpenseCategory != expenseStats.isIncomeCategory)

        let incomeStats = makeStats(type: .income)
        #expect(incomeStats.isExpenseCategory != incomeStats.isIncomeCategory)
    }

    // MARK: - Percentage Values

    @Test("Percentage of 100 is stored correctly")
    func testFullPercentage() {
        let stats = makeStats(percentage: 100.0)
        #expect(stats.percentage == 100.0)
    }

    @Test("Percentage of 0 is stored correctly")
    func testZeroPercentage() {
        let stats = makeStats(percentage: 0.0)
        #expect(stats.percentage == 0.0)
    }

    @Test("Fractional percentage is stored correctly")
    func testFractionalPercentage() {
        let stats = makeStats(percentage: 33.33)
        #expect(stats.percentage == 33.33)
    }

    // MARK: - Zero Count

    @Test("CategoryStats works with zero count")
    func testZeroCount() {
        let stats = makeStats(totalAmount: 0.0, count: 0, percentage: 0.0)
        #expect(stats.count == 0)
        #expect(stats.totalAmount == 0.0)
        #expect(stats.percentage == 0.0)
    }

    // MARK: - Edge Cases

    @Test("CategoryStats works with large amounts")
    func testLargeAmounts() {
        let stats = makeStats(totalAmount: 1_000_000.0, count: 500, percentage: 75.5)
        #expect(stats.totalAmount == 1_000_000.0)
        #expect(stats.count == 500)
        #expect(stats.percentage == 75.5)
    }

    @Test("CategoryStats preserves color hex string")
    func testColorHex() {
        let stats = makeStats(colorHex: "#00FF00")
        #expect(stats.colorHex == "#00FF00")
    }

    @Test("CategoryStats preserves icon name")
    func testIconName() {
        let stats = makeStats(iconName: "car.fill")
        #expect(stats.iconName == "car.fill")
    }
}

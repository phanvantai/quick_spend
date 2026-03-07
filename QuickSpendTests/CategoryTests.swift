import Testing
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("Category Model Tests")
struct CategoryTests {

    @Test("Category initializes with correct values")
    func testInitialization() {
        let category = AppCategory(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0
        )

        #expect(category.id == "food_drink")
        #expect(category.name == "Food & Drink")
        #expect(category.iconName == "fork.knife")
        #expect(category.colorHex == "#FF8C42")
        #expect(category.type == .expense)
        #expect(category.group == .dailyLiving)
        #expect(category.sortOrder == 0)
        #expect(category.isHidden == false)
    }

    @Test("isExpenseCategory returns true for expense type")
    func testIsExpenseCategory() {
        let category = AppCategory(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            sortOrder: 0
        )

        #expect(category.isExpenseCategory == true)
        #expect(category.isIncomeCategory == false)
    }

    @Test("isIncomeCategory returns true for income type")
    func testIsIncomeCategory() {
        let category = AppCategory(
            id: "salary",
            name: "Salary",
            iconName: "wallet.bifold.fill",
            colorHex: "#4CAF50",
            type: .income,
            group: .earned,
            sortOrder: 0
        )

        #expect(category.isIncomeCategory == true)
        #expect(category.isExpenseCategory == false)
    }

    @Test("Category group is optional")
    func testOptionalGroup() {
        let category = AppCategory(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            group: nil,
            sortOrder: 99
        )

        #expect(category.group == nil)
    }

    @Test("isHidden defaults to false")
    func testIsHiddenDefault() {
        let category = AppCategory(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            group: nil,
            sortOrder: 0
        )

        #expect(category.isHidden == false)
    }

    @Test("Category color computes from hex")
    func testColorFromHex() {
        let category = AppCategory(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#FF0000",
            type: .expense,
            sortOrder: 0
        )

        // Verify color property doesn't crash and returns a value
        let _ = category.color
    }

    @Test("Category timestamps are set on creation")
    func testTimestamps() {
        let before = Date.now
        let category = AppCategory(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            sortOrder: 0
        )
        let after = Date.now

        #expect(category.createdAt >= before)
        #expect(category.createdAt <= after)
        #expect(category.updatedAt >= before)
        #expect(category.updatedAt <= after)
    }
}

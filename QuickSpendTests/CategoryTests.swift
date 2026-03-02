import Testing
import Foundation
@testable import QuickSpend

@Suite("Category Model Tests")
struct CategoryTests {

    @Test("Category initializes with correct values")
    func testInitialization() {
        let category = Category(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            keywords: ["food", "lunch", "dinner"],
            sortOrder: 0
        )

        #expect(category.id == "food_drink")
        #expect(category.name == "Food & Drink")
        #expect(category.iconName == "fork.knife")
        #expect(category.colorHex == "#FF8C42")
        #expect(category.type == .expense)
        #expect(category.group == .dailyLiving)
        #expect(category.keywords == ["food", "lunch", "dinner"])
        #expect(category.sortOrder == 0)
        #expect(category.isHidden == false)
    }

    @Test("isExpenseCategory returns true for expense type")
    func testIsExpenseCategory() {
        let category = Category(
            id: "food_drink",
            name: "Food & Drink",
            iconName: "fork.knife",
            colorHex: "#FF8C42",
            type: .expense,
            group: .dailyLiving,
            keywords: [],
            sortOrder: 0
        )

        #expect(category.isExpenseCategory == true)
        #expect(category.isIncomeCategory == false)
    }

    @Test("isIncomeCategory returns true for income type")
    func testIsIncomeCategory() {
        let category = Category(
            id: "salary",
            name: "Salary",
            iconName: "wallet.bifold.fill",
            colorHex: "#4CAF50",
            type: .income,
            group: .earned,
            keywords: [],
            sortOrder: 0
        )

        #expect(category.isIncomeCategory == true)
        #expect(category.isExpenseCategory == false)
    }

    @Test("Category group is optional")
    func testOptionalGroup() {
        let category = Category(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            group: nil,
            keywords: [],
            sortOrder: 99
        )

        #expect(category.group == nil)
    }

    @Test("isHidden defaults to false")
    func testIsHiddenDefault() {
        let category = Category(
            id: "test",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            group: nil,
            keywords: [],
            sortOrder: 0
        )

        #expect(category.isHidden == false)
    }
}

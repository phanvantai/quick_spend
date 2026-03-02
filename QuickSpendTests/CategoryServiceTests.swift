import Testing
import Foundation
@testable import QuickSpend

@Suite("CategoryService Tests")
struct CategoryServiceTests {

    @Test("Default categories returns 26 categories (18 expense + 8 income)")
    func testDefaultCategoriesCount() {
        let enCategories = CategoryService.defaultCategories(language: "en")
        #expect(enCategories.count == 26)

        let viCategories = CategoryService.defaultCategories(language: "vi")
        #expect(viCategories.count == 26)
    }

    @Test("Default categories have 18 expense and 8 income")
    func testCategoryTypeBreakdown() {
        let categories = CategoryService.defaultCategories(language: "en")
        let expense = categories.filter { $0.type == .expense }
        let income = categories.filter { $0.type == .income }

        #expect(expense.count == 18)
        #expect(income.count == 8)
    }

    @Test("All default categories have unique IDs")
    func testUniqueIds() {
        let categories = CategoryService.defaultCategories(language: "en")
        let ids = Set(categories.map(\.id))
        #expect(ids.count == categories.count)
    }

    @Test("All default categories have non-empty names")
    func testNonEmptyNames() {
        for lang in ["en", "vi"] {
            let categories = CategoryService.defaultCategories(language: lang)
            for category in categories {
                #expect(!category.name.isEmpty, "Category \(category.id) has empty name for language \(lang)")
            }
        }
    }

    @Test("All default categories have valid icon names")
    func testIconNames() {
        let categories = CategoryService.defaultCategories(language: "en")
        for category in categories {
            #expect(!category.iconName.isEmpty, "Category \(category.id) has empty icon name")
        }
    }

    @Test("All default categories have color hex values")
    func testColorHex() {
        let categories = CategoryService.defaultCategories(language: "en")
        for category in categories {
            #expect(category.colorHex.hasPrefix("#"), "Category \(category.id) colorHex should start with #")
            #expect(category.colorHex.count == 7, "Category \(category.id) colorHex should be #RRGGBB format")
        }
    }

    @Test("All default categories have a group assigned")
    func testGroupAssignment() {
        let categories = CategoryService.defaultCategories(language: "en")
        for category in categories {
            #expect(category.group != nil, "Category \(category.id) should have a group")
        }
    }

    @Test("Sort orders are unique within each type")
    func testSortOrderUniqueness() {
        let categories = CategoryService.defaultCategories(language: "en")

        let expenseSortOrders = categories.filter { $0.type == .expense }.map(\.sortOrder)
        #expect(Set(expenseSortOrders).count == expenseSortOrders.count, "Expense sort orders should be unique")

        let incomeSortOrders = categories.filter { $0.type == .income }.map(\.sortOrder)
        #expect(Set(incomeSortOrders).count == incomeSortOrders.count, "Income sort orders should be unique")
    }

    @Test("Known category IDs exist")
    func testKnownCategoryIds() {
        let categories = CategoryService.defaultCategories(language: "en")
        let ids = Set(categories.map(\.id))

        // Expense IDs
        let expectedExpenseIds = [
            "food_drink", "groceries", "transport", "housing", "bills_utilities",
            "shopping", "health", "education", "entertainment", "personal_care",
            "gifts", "family", "insurance", "savings_invest", "debt_payment",
            "pets", "travel", "other_expense"
        ]
        for id in expectedExpenseIds {
            #expect(ids.contains(id), "Missing expense category: \(id)")
        }

        // Income IDs
        let expectedIncomeIds = [
            "salary", "freelance", "bonus", "investment_income",
            "interest", "gift_received", "refund", "other_income"
        ]
        for id in expectedIncomeIds {
            #expect(ids.contains(id), "Missing income category: \(id)")
        }
    }

    @Test("Vietnamese categories have different names from English")
    func testVietnameseLocalization() {
        let en = CategoryService.defaultCategories(language: "en")
        let vi = CategoryService.defaultCategories(language: "vi")

        // Same IDs
        #expect(Set(en.map(\.id)) == Set(vi.map(\.id)))

        // Different names for at least some categories
        let enNames = Set(en.map(\.name))
        let viNames = Set(vi.map(\.name))
        #expect(enNames != viNames, "EN and VI names should differ")
    }

    @Test("Categories have keywords for AI matching")
    func testKeywords() {
        let categories = CategoryService.defaultCategories(language: "en")
        let withKeywords = categories.filter { !$0.keywords.isEmpty }

        // Most categories should have keywords
        #expect(withKeywords.count > 20, "Most categories should have keywords for AI matching")
    }
}

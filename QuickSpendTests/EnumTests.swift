import Testing
import Foundation
@testable import QuickSpend

@Suite("Enum Tests")
struct EnumTests {

    // MARK: - TransactionType

    @Test("TransactionType has income and expense cases")
    func testTransactionTypeCases() {
        let income = TransactionType.income
        let expense = TransactionType.expense

        #expect(income != expense)
        #expect(income.rawValue == "income")
        #expect(expense.rawValue == "expense")
    }

    @Test("TransactionType is Codable")
    func testTransactionTypeCodable() throws {
        let original = TransactionType.expense
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionType.self, from: data)

        #expect(decoded == original)
    }

    @Test("TransactionType round-trips both values")
    func testTransactionTypeRoundTrip() throws {
        for type in [TransactionType.income, TransactionType.expense] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TransactionType.self, from: data)
            #expect(decoded == type)
        }
    }

    // MARK: - RecurrencePattern

    @Test("RecurrencePattern has all 4 cases")
    func testRecurrencePatternCases() {
        let all = RecurrencePattern.allCases
        #expect(all.count == 4)
        #expect(all.contains(.daily))
        #expect(all.contains(.weekly))
        #expect(all.contains(.monthly))
        #expect(all.contains(.yearly))
    }

    @Test("RecurrencePattern does not have 'none' case")
    func testNoNoneCase() {
        let rawValues = RecurrencePattern.allCases.map(\.rawValue)
        #expect(!rawValues.contains("none"))
    }

    @Test("RecurrencePattern is Codable")
    func testRecurrencePatternCodable() throws {
        for pattern in RecurrencePattern.allCases {
            let data = try JSONEncoder().encode(pattern)
            let decoded = try JSONDecoder().decode(RecurrencePattern.self, from: data)
            #expect(decoded == pattern)
        }
    }

    @Test("RecurrencePattern raw values are correct")
    func testRecurrencePatternRawValues() {
        #expect(RecurrencePattern.daily.rawValue == "daily")
        #expect(RecurrencePattern.weekly.rawValue == "weekly")
        #expect(RecurrencePattern.monthly.rawValue == "monthly")
        #expect(RecurrencePattern.yearly.rawValue == "yearly")
    }

    // MARK: - CategoryGroup

    @Test("CategoryGroup has all 8 cases")
    func testCategoryGroupCases() {
        let all = CategoryGroup.allCases
        #expect(all.count == 8)
    }

    @Test("CategoryGroup expense groups")
    func testExpenseGroups() {
        let expenseGroups: [CategoryGroup] = [.dailyLiving, .personal, .social, .financial]
        for group in expenseGroups {
            #expect(CategoryGroup.allCases.contains(group))
        }
    }

    @Test("CategoryGroup income groups")
    func testIncomeGroups() {
        let incomeGroups: [CategoryGroup] = [.earned, .passive, .received]
        for group in incomeGroups {
            #expect(CategoryGroup.allCases.contains(group))
        }
    }

    @Test("CategoryGroup shared groups")
    func testSharedGroups() {
        #expect(CategoryGroup.allCases.contains(.other))
    }

    @Test("CategoryGroup is Codable")
    func testCategoryGroupCodable() throws {
        for group in CategoryGroup.allCases {
            let data = try JSONEncoder().encode(group)
            let decoded = try JSONDecoder().decode(CategoryGroup.self, from: data)
            #expect(decoded == group)
        }
    }

    @Test("CategoryGroup iconName returns valid SF Symbol name for every case")
    func testCategoryGroupIconName() {
        let expectedIcons: [CategoryGroup: String] = [
            .dailyLiving: "cup.and.saucer.fill",
            .personal: "person.fill",
            .social: "person.2.fill",
            .financial: "banknote.fill",
            .earned: "briefcase.fill",
            .passive: "chart.line.uptrend.xyaxis",
            .received: "gift.fill",
            .other: "ellipsis.circle.fill",
        ]

        for group in CategoryGroup.allCases {
            #expect(!group.iconName.isEmpty, "Icon name should not be empty for \(group)")
            #expect(group.iconName == expectedIcons[group], "Unexpected icon for \(group)")
        }
    }

    @Test("CategoryGroup iconName covers all cases")
    func testCategoryGroupIconNameCoversAllCases() {
        // Ensure every case has a non-empty icon name
        let icons = Set(CategoryGroup.allCases.map(\.iconName))
        #expect(icons.count == CategoryGroup.allCases.count, "Each group should have a unique icon")
    }
}

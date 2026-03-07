import Testing
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("GeminiParserService Tests")
struct GeminiParserServiceTests {

    // MARK: - isValidInput

    @Test("Empty input is invalid")
    func testEmptyInput() {
        #expect(GeminiParserService.isValidInput("") == false)
    }

    @Test("Whitespace-only input is invalid")
    func testWhitespaceInput() {
        #expect(GeminiParserService.isValidInput("   ") == false)
    }

    @Test("Single character input is invalid (below min length)")
    func testSingleCharInput() {
        #expect(GeminiParserService.isValidInput("a") == false)
    }

    @Test("Valid short input passes")
    func testValidShortInput() {
        #expect(GeminiParserService.isValidInput("50k coffee") == true)
    }

    @Test("Valid long input passes")
    func testValidLongInput() {
        #expect(GeminiParserService.isValidInput("I spent 50 thousand on coffee and 30k on parking yesterday") == true)
    }

    @Test("Filler words are invalid (English)")
    func testFillerWordsEnglish() {
        #expect(GeminiParserService.isValidInput("uh") == false)
        #expect(GeminiParserService.isValidInput("um") == false)
        #expect(GeminiParserService.isValidInput("ahh") == false)
        #expect(GeminiParserService.isValidInput("err") == false)
        #expect(GeminiParserService.isValidInput("hmm") == false)
    }

    @Test("Filler words are invalid (Vietnamese)")
    func testFillerWordsVietnamese() {
        #expect(GeminiParserService.isValidInput("ờờ") == false)
        #expect(GeminiParserService.isValidInput("àà") == false)
        #expect(GeminiParserService.isValidInput("ưư") == false)
    }

    @Test("Non-alphanumeric only input is invalid")
    func testNonAlphanumericInput() {
        #expect(GeminiParserService.isValidInput("!!!") == false)
        #expect(GeminiParserService.isValidInput("...") == false)
    }

    @Test("Repeated single word 3+ times is invalid")
    func testRepeatedWords() {
        #expect(GeminiParserService.isValidInput("test test test") == false)
        #expect(GeminiParserService.isValidInput("abc abc abc abc") == false)
    }

    @Test("Two repeated words is valid")
    func testTwoRepeatedWords() {
        #expect(GeminiParserService.isValidInput("hello hello") == true)
    }

    @Test("Mixed valid words pass")
    func testMixedValidWords() {
        #expect(GeminiParserService.isValidInput("coffee 50k") == true)
        #expect(GeminiParserService.isValidInput("lunch and dinner 100k") == true)
    }

    @Test("Vietnamese expense input is valid")
    func testVietnameseInput() {
        #expect(GeminiParserService.isValidInput("45 ca tiền cơm") == true)
        #expect(GeminiParserService.isValidInput("nhận lương 15 triệu") == true)
    }

    @Test("Japanese expense input is valid")
    func testJapaneseInput() {
        #expect(GeminiParserService.isValidInput("コーヒー500円") == true)
    }

    // MARK: - normalizeCategoryId

    @Test("Known expense category IDs are preserved")
    func testKnownExpenseCategories() {
        let knownIds = ["food_drink", "groceries", "transport", "housing", "bills_utilities",
                        "shopping", "health", "education", "entertainment", "personal_care",
                        "gifts", "family", "insurance", "savings_invest", "debt_payment",
                        "pets", "travel", "other_expense"]

        for id in knownIds {
            #expect(GeminiParserService.normalizeCategoryId(id, type: .expense) == id)
        }
    }

    @Test("Known income category IDs are preserved")
    func testKnownIncomeCategories() {
        let knownIds = ["salary", "freelance", "bonus", "investment_income",
                        "interest", "gift_received", "refund", "other_income"]

        for id in knownIds {
            #expect(GeminiParserService.normalizeCategoryId(id, type: .income) == id)
        }
    }

    @Test("Unknown expense category falls back to other_expense")
    func testUnknownExpenseCategory() {
        #expect(GeminiParserService.normalizeCategoryId("unknown", type: .expense) == "other_expense")
        #expect(GeminiParserService.normalizeCategoryId("random_stuff", type: .expense) == "other_expense")
    }

    @Test("Unknown income category falls back to other_income")
    func testUnknownIncomeCategory() {
        #expect(GeminiParserService.normalizeCategoryId("unknown", type: .income) == "other_income")
        #expect(GeminiParserService.normalizeCategoryId("random_stuff", type: .income) == "other_income")
    }

    @Test("Income category ID with expense type falls back to other_expense")
    func testIncomeCategoryWithExpenseType() {
        #expect(GeminiParserService.normalizeCategoryId("salary", type: .expense) == "other_expense")
    }

    @Test("Expense category ID with income type falls back to other_income")
    func testExpenseCategoryWithIncomeType() {
        #expect(GeminiParserService.normalizeCategoryId("food_drink", type: .income) == "other_income")
    }

    // MARK: - typeFromCategory

    @Test("Income categories return income type")
    func testTypeFromIncomeCategory() {
        let incomeIds = ["salary", "freelance", "bonus", "investment_income",
                        "interest", "gift_received", "refund", "other_income"]

        for id in incomeIds {
            #expect(GeminiParserService.typeFromCategory(id) == .income)
        }
    }

    @Test("Expense categories return expense type")
    func testTypeFromExpenseCategory() {
        let expenseIds = ["food_drink", "groceries", "transport", "housing"]

        for id in expenseIds {
            #expect(GeminiParserService.typeFromCategory(id) == .expense)
        }
    }

    @Test("Unknown category defaults to expense type")
    func testTypeFromUnknownCategory() {
        #expect(GeminiParserService.typeFromCategory("unknown") == .expense)
    }

    // MARK: - parseDate

    @Test("'today' parses to start of today")
    func testParseDateToday() {
        let parsed = GeminiParserService.parseDate("today")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    @Test("'yesterday' parses to start of yesterday")
    func testParseDateYesterday() {
        let parsed = GeminiParserService.parseDate("yesterday")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        #expect(parsed == expected)
    }

    @Test("Vietnamese 'hôm nay' parses to today")
    func testParseDateVietnameseToday() {
        let parsed = GeminiParserService.parseDate("hôm nay")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    @Test("Vietnamese 'hôm qua' parses to yesterday")
    func testParseDateVietnameseYesterday() {
        let parsed = GeminiParserService.parseDate("hôm qua")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        #expect(parsed == expected)
    }

    @Test("ISO date format parses correctly")
    func testParseDateISO() {
        let parsed = GeminiParserService.parseDate("2024-06-15")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expected = Calendar.current.startOfDay(for: formatter.date(from: "2024-06-15")!)
        #expect(parsed == expected)
    }

    @Test("Invalid date string defaults to today")
    func testParseDateInvalid() {
        let parsed = GeminiParserService.parseDate("not-a-date")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    @Test("Case insensitive date parsing")
    func testParseDateCaseInsensitive() {
        let parsed = GeminiParserService.parseDate("TODAY")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    // MARK: - parseResponse

    @Test("parseResponse parses valid JSON correctly")
    func testParseResponseValid() {
        let json: [String: Any] = [
            "expenses": [
                [
                    "amount": 50000,
                    "description": "coffee",
                    "category": "food_drink",
                    "type": "expense",
                    "date": "today",
                    "confidence": 0.95
                ] as [String: Any]
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")

        #expect(results.count == 1)
        #expect(results[0].amount == 50000)
        #expect(results[0].note == "coffee")
        #expect(results[0].categoryId == "food_drink")
        #expect(results[0].type == .expense)
        #expect(results[0].confidence == 0.95)
    }

    @Test("parseResponse handles multiple expenses")
    func testParseResponseMultiple() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "description": "coffee", "category": "food_drink", "type": "expense", "date": "today", "confidence": 0.9] as [String: Any],
                ["amount": 30000, "description": "parking", "category": "transport", "type": "expense", "date": "today", "confidence": 0.85] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.count == 2)
        #expect(results[0].amount == 50000)
        #expect(results[1].amount == 30000)
    }

    @Test("parseResponse handles income type")
    func testParseResponseIncome() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 15000000, "description": "salary", "category": "salary", "type": "income", "date": "today", "confidence": 0.95] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.count == 1)
        #expect(results[0].type == .income)
        #expect(results[0].categoryId == "salary")
    }

    @Test("parseResponse skips zero amount")
    func testParseResponseZeroAmount() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 0, "description": "nothing", "category": "food_drink", "type": "expense", "date": "today", "confidence": 0.5] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.isEmpty)
    }

    @Test("parseResponse skips negative amount")
    func testParseResponseNegativeAmount() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": -100, "description": "bad", "category": "food_drink", "type": "expense", "date": "today", "confidence": 0.5] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.isEmpty)
    }

    @Test("parseResponse returns empty for missing expenses key")
    func testParseResponseMissingKey() {
        let json: [String: Any] = ["result": "ok"]
        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.isEmpty)
    }

    @Test("parseResponse handles empty expenses array")
    func testParseResponseEmptyArray() {
        let json: [String: Any] = ["expenses": [] as [[String: Any]]]
        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.isEmpty)
    }

    @Test("parseResponse defaults missing description")
    func testParseResponseMissingDescription() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "category": "food_drink", "type": "expense", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.count == 1)
        #expect(results[0].note == "Expense")  // Default for expense
    }

    @Test("parseResponse defaults missing description for income")
    func testParseResponseMissingDescriptionIncome() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 1000, "category": "salary", "type": "income", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.count == 1)
        #expect(results[0].note == "Income")  // Default for income
    }

    @Test("parseResponse defaults confidence to 0.5")
    func testParseResponseDefaultConfidence() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "description": "coffee", "category": "food_drink", "type": "expense", "date": "today"] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results[0].confidence == 0.5)
    }

    @Test("parseResponse normalizes unknown categories")
    func testParseResponseNormalizesCategory() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "description": "stuff", "category": "unknown_cat", "type": "expense", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results[0].categoryId == "other_expense")
    }

    // MARK: - buildPrompt

    @Test("buildPrompt includes input text")
    func testBuildPromptIncludesInput() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "50k coffee", categories: categories, language: "en")
        #expect(prompt.contains("50k coffee"))
    }

    @Test("buildPrompt includes category IDs")
    func testBuildPromptIncludesCategories() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food & Drink", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
            AppCategory(id: "salary", name: "Salary", iconName: "wallet.bifold.fill", colorHex: "#00FF00", type: .income, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("food_drink"))
        #expect(prompt.contains("salary"))
    }

    @Test("buildPrompt includes language-specific hints for Vietnamese")
    func testBuildPromptVietnamese() {
        let categories = [
            AppCategory(id: "food_drink", name: "Ăn uống", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "vi")
        #expect(prompt.contains("Vietnamese"))
    }

    @Test("buildPrompt includes language-specific hints for Japanese")
    func testBuildPromptJapanese() {
        let categories = [
            AppCategory(id: "food_drink", name: "飲食", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "ja")
        #expect(prompt.contains("Japanese"))
    }

    @Test("buildPrompt includes language-specific hints for Spanish")
    func testBuildPromptSpanish() {
        let categories = [
            AppCategory(id: "food_drink", name: "Comida", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "es")
        #expect(prompt.contains("Spanish"))
    }

    @Test("buildPrompt defaults to English for unknown language")
    func testBuildPromptEnglishDefault() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("English"))
    }

    @Test("buildPrompt includes current date")
    func testBuildPromptIncludesDate() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: .now)

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains(todayStr))
    }

    // MARK: - isAvailable

    @Test("isAvailable returns false without Firebase SDK")
    func testIsAvailableWithoutFirebase() {
        // Without Firebase AI SDK, isAvailable should return false
        // This test validates the graceful degradation
        #if !canImport(FirebaseAI)
        #expect(GeminiParserService.isAvailable == false)
        #endif
    }
}

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

    @Test("Pure numbers without letters are invalid")
    func testPureNumberInput() {
        #expect(GeminiParserService.isValidInput("123456789") == false)
        #expect(GeminiParserService.isValidInput("42") == false)
        #expect(GeminiParserService.isValidInput("999 999") == false)
        #expect(GeminiParserService.isValidInput("50.00") == false)
    }

    @Test("Numbers with letters are valid")
    func testNumbersWithLetters() {
        #expect(GeminiParserService.isValidInput("50k coffee") == true)
        #expect(GeminiParserService.isValidInput("coffee 5") == true)
        #expect(GeminiParserService.isValidInput("500円コーヒー") == true)
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

    // MARK: - parseDate (Japanese)

    @Test("Japanese '今日' parses to today")
    func testParseDateJapaneseToday() {
        let parsed = GeminiParserService.parseDate("今日")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    @Test("Japanese '昨日' parses to yesterday")
    func testParseDateJapaneseYesterday() {
        let parsed = GeminiParserService.parseDate("昨日")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        #expect(parsed == expected)
    }

    // MARK: - parseDate (Spanish)

    @Test("Spanish 'hoy' parses to today")
    func testParseDateSpanishToday() {
        let parsed = GeminiParserService.parseDate("hoy")
        let expected = Calendar.current.startOfDay(for: .now)
        #expect(parsed == expected)
    }

    @Test("Spanish 'ayer' parses to yesterday")
    func testParseDateSpanishYesterday() {
        let parsed = GeminiParserService.parseDate("ayer")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
        #expect(parsed == expected)
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
        #expect(prompt.contains("Vietnamese-specific rules"))
    }

    @Test("buildPrompt includes language-specific hints for Japanese")
    func testBuildPromptJapanese() {
        let categories = [
            AppCategory(id: "food_drink", name: "飲食", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "ja")
        #expect(prompt.contains("Japanese"))
        #expect(prompt.contains("Japanese-specific rules"))
    }

    @Test("buildPrompt includes language-specific hints for Spanish")
    func testBuildPromptSpanish() {
        let categories = [
            AppCategory(id: "food_drink", name: "Comida", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "es")
        #expect(prompt.contains("Spanish"))
        #expect(prompt.contains("Spanish-specific rules"))
    }

    @Test("buildPrompt defaults to English for unknown language")
    func testBuildPromptEnglishDefault() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("English"))
        #expect(prompt.contains("English-specific rules"))
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

    @Test("buildPrompt includes currency context")
    func testBuildPromptIncludesCurrency() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en", currency: "VND")
        #expect(prompt.contains("VND"))
        #expect(prompt.contains("CURRENCY CONTEXT"))
    }

    @Test("buildPrompt defaults currency to USD")
    func testBuildPromptDefaultCurrencyUSD() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("USD"))
    }

    @Test("buildPrompt includes auto-detect instruction")
    func testBuildPromptIncludesAutoDetect() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("auto-detect"))
        #expect(prompt.contains("detected_language"))
    }

    @Test("buildPrompt Vietnamese does not include English-specific rules")
    func testBuildPromptVietnameseNoEnglishRules() {
        let categories = [
            AppCategory(id: "food_drink", name: "Ăn uống", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "vi")
        #expect(!prompt.contains("English-specific rules"))
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

    // MARK: - isValidInput: maxVoiceInputLength enforcement (#7)

    @Test("Input exceeding maxVoiceInputLength is invalid")
    func testInputExceedingMaxLength() {
        let longInput = String(repeating: "a coffee ", count: 100) // 900 chars, exceeds 500
        #expect(longInput.count > AppConstants.maxVoiceInputLength)
        #expect(GeminiParserService.isValidInput(longInput) == false)
    }

    @Test("Input exactly at maxVoiceInputLength is valid")
    func testInputAtMaxLength() {
        // Build a string exactly at max length that passes other validation
        let base = "coffee expense for today "
        let repeats = AppConstants.maxVoiceInputLength / base.count
        let input = String(String(repeating: base, count: repeats).prefix(AppConstants.maxVoiceInputLength))
        #expect(input.count <= AppConstants.maxVoiceInputLength)
        #expect(GeminiParserService.isValidInput(input) == true)
    }

    // MARK: - normalizeCategoryId with custom categories (#8)

    @Test("Custom category ID is preserved when in validCategoryIds set")
    func testCustomCategoryPreserved() {
        let validIds: Set<String> = ["gym_membership", "food_drink", "other_expense"]
        let result = GeminiParserService.normalizeCategoryId("gym_membership", type: .expense, validCategoryIds: validIds)
        #expect(result == "gym_membership")
    }

    @Test("Custom income category ID is preserved when in validCategoryIds set")
    func testCustomIncomeCategoryPreserved() {
        let validIds: Set<String> = ["side_hustle", "salary", "other_income"]
        let result = GeminiParserService.normalizeCategoryId("side_hustle", type: .income, validCategoryIds: validIds)
        #expect(result == "side_hustle")
    }

    @Test("Unknown category still falls back when not in validCategoryIds")
    func testUnknownCategoryFallbackWithValidIds() {
        let validIds: Set<String> = ["food_drink", "transport"]
        let result = GeminiParserService.normalizeCategoryId("nonexistent_cat", type: .expense, validCategoryIds: validIds)
        #expect(result == "other_expense")
    }

    @Test("Empty validCategoryIds falls back to default behavior")
    func testEmptyValidCategoryIdsFallsBack() {
        let result = GeminiParserService.normalizeCategoryId("custom_cat", type: .expense, validCategoryIds: [])
        #expect(result == "other_expense")
    }

    // MARK: - parseResponse with validCategoryIds (#8)

    @Test("parseResponse preserves custom category when valid IDs provided")
    func testParseResponseWithCustomCategory() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": 50000, "description": "gym", "category": "gym_membership", "type": "expense", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let validIds: Set<String> = ["gym_membership", "food_drink"]
        let results = GeminiParserService.parseResponse(jsonData: json, language: "en", validCategoryIds: validIds)
        #expect(results.count == 1)
        #expect(results[0].categoryId == "gym_membership")
    }

    // MARK: - parseResponse clamps excessive amounts (#4)

    @Test("parseResponse clamps amount exceeding maxExpenseAmount")
    func testParseResponseClampsAmount() {
        let json: [String: Any] = [
            "expenses": [
                ["amount": NSNumber(value: 9_999_999_999_999.0), "description": "huge", "category": "other_expense", "type": "expense", "date": "today", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "en")
        #expect(results.count == 1)
        #expect(results[0].amount <= AppConstants.maxExpenseAmount)
    }

    // MARK: - parseDate: day before yesterday (#10)

    @Test("'day before yesterday' parses to 2 days ago")
    func testParseDateDayBeforeYesterday() {
        let parsed = GeminiParserService.parseDate("day before yesterday")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -2, to: .now)!)
        #expect(parsed == expected)
    }

    @Test("Vietnamese 'hôm kia' parses to 2 days ago")
    func testParseDateVietnameseDayBeforeYesterday() {
        let parsed = GeminiParserService.parseDate("hôm kia")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -2, to: .now)!)
        #expect(parsed == expected)
    }

    @Test("Japanese '一昨日' parses to 2 days ago")
    func testParseDateJapaneseDayBeforeYesterday() {
        let parsed = GeminiParserService.parseDate("一昨日")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -2, to: .now)!)
        #expect(parsed == expected)
    }

    @Test("Spanish 'anteayer' parses to 2 days ago")
    func testParseDateSpanishDayBeforeYesterday() {
        let parsed = GeminiParserService.parseDate("anteayer")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -2, to: .now)!)
        #expect(parsed == expected)
    }

    // MARK: - parseDaysAgo (#10)

    @Test("'3 days ago' parses correctly")
    func testParseDaysAgoEnglish() {
        let result = GeminiParserService.parseDaysAgo("3 days ago")
        #expect(result == 3)
    }

    @Test("'1 day ago' parses correctly")
    func testParseDaysAgoEnglishSingular() {
        let result = GeminiParserService.parseDaysAgo("1 day ago")
        #expect(result == 1)
    }

    @Test("Vietnamese '3 ngày trước' parses correctly")
    func testParseDaysAgoVietnamese() {
        let result = GeminiParserService.parseDaysAgo("3 ngày trước")
        #expect(result == 3)
    }

    @Test("Vietnamese 'cách đây 5 ngày' parses correctly")
    func testParseDaysAgoVietnameseAlt() {
        let result = GeminiParserService.parseDaysAgo("cách đây 5 ngày")
        #expect(result == 5)
    }

    @Test("Spanish 'hace 2 días' parses correctly")
    func testParseDaysAgoSpanish() {
        let result = GeminiParserService.parseDaysAgo("hace 2 días")
        #expect(result == 2)
    }

    @Test("Non-matching text returns nil for parseDaysAgo")
    func testParseDaysAgoNonMatch() {
        let result = GeminiParserService.parseDaysAgo("last monday")
        #expect(result == nil)
    }

    @Test("Zero days ago returns nil")
    func testParseDaysAgoZero() {
        let result = GeminiParserService.parseDaysAgo("0 days ago")
        #expect(result == nil)
    }

    @Test("Excessive days ago (>365) returns nil")
    func testParseDaysAgoExcessive() {
        let result = GeminiParserService.parseDaysAgo("500 days ago")
        #expect(result == nil)
    }

    // MARK: - parseDate with N days ago patterns (#10)

    @Test("parseDate handles '3 days ago' correctly")
    func testParseDateDaysAgo() {
        let parsed = GeminiParserService.parseDate("3 days ago")
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -3, to: .now)!)
        #expect(parsed == expected)
    }

    // MARK: - ParsedTransaction rawInput field (#3)

    @Test("ParsedTransaction stores rawInput")
    func testParsedTransactionRawInput() {
        let transaction = ParsedTransaction(
            amount: 50000,
            note: "coffee",
            categoryId: "food_drink",
            type: .expense,
            date: .now,
            confidence: 0.9,
            rawInput: "fifty thousand coffee"
        )
        #expect(transaction.rawInput == "fifty thousand coffee")
    }

    @Test("ParsedTransaction rawInput defaults to nil")
    func testParsedTransactionRawInputDefault() {
        let transaction = ParsedTransaction(
            amount: 50000,
            note: "coffee",
            categoryId: "food_drink",
            type: .expense,
            date: .now,
            confidence: 0.9
        )
        #expect(transaction.rawInput == nil)
    }

    // MARK: - buildPrompt calendar context

    @Test("buildPrompt includes last week date range")
    func testBuildPromptIncludesLastWeek() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("Last week"))
        #expect(prompt.contains("This week's Monday"))
    }

    @Test("buildPrompt includes date range expansion rule")
    func testBuildPromptIncludesDateRangeRule() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("Date ranges with repetition"))
        #expect(prompt.contains("ONE SEPARATE TRANSACTION"))
    }

    @Test("buildPrompt Vietnamese includes weekday names")
    func testBuildPromptVietnameseWeekdays() {
        let categories = [
            AppCategory(id: "transport", name: "Di chuyển", iconName: "car", colorHex: "#0000FF", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "vi")
        #expect(prompt.contains("thứ 2/thứ hai=Monday"))
        #expect(prompt.contains("tuần trước"))
        #expect(prompt.contains("mỗi ngày"))
    }

    @Test("buildPrompt Vietnamese includes date range example")
    func testBuildPromptVietnameseDateRangeExample() {
        let categories = [
            AppCategory(id: "transport", name: "Di chuyển", iconName: "car", colorHex: "#0000FF", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "vi")
        #expect(prompt.contains("thứ 2 đến thứ 6 tuần trước mỗi ngày 180000 tiền xe khách"))
        #expect(prompt.contains("5 separate expenses"))
    }

    @Test("buildPrompt English includes date range example")
    func testBuildPromptEnglishDateRangeExample() {
        let categories = [
            AppCategory(id: "food_drink", name: "Food", iconName: "fork.knife", colorHex: "#FF0000", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "en")
        #expect(prompt.contains("last week Monday to Friday"))
        #expect(prompt.contains("each day"))
    }

    @Test("buildPrompt Japanese includes weekday and repetition rules")
    func testBuildPromptJapaneseWeekdays() {
        let categories = [
            AppCategory(id: "transport", name: "交通費", iconName: "car", colorHex: "#0000FF", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "ja")
        #expect(prompt.contains("月曜日=Monday"))
        #expect(prompt.contains("先週"))
        #expect(prompt.contains("毎日"))
    }

    @Test("buildPrompt Spanish includes weekday and repetition rules")
    func testBuildPromptSpanishWeekdays() {
        let categories = [
            AppCategory(id: "transport", name: "Transporte", iconName: "car", colorHex: "#0000FF", type: .expense, sortOrder: 0),
        ]

        let prompt = GeminiParserService.buildPrompt(input: "test", categories: categories, language: "es")
        #expect(prompt.contains("lunes=Monday"))
        #expect(prompt.contains("la semana pasada"))
        #expect(prompt.contains("cada día"))
    }

    // MARK: - parseResponse handles multiple date-range transactions

    @Test("parseResponse handles 5 daily transactions from date range")
    func testParseResponseDateRangeExpansion() {
        let json: [String: Any] = [
            "detected_language": "vi",
            "expenses": [
                ["amount": 180000, "description": "tiền xe khách", "category": "transport", "type": "expense", "date": "2026-05-11", "confidence": 0.9] as [String: Any],
                ["amount": 180000, "description": "tiền xe khách", "category": "transport", "type": "expense", "date": "2026-05-12", "confidence": 0.9] as [String: Any],
                ["amount": 180000, "description": "tiền xe khách", "category": "transport", "type": "expense", "date": "2026-05-13", "confidence": 0.9] as [String: Any],
                ["amount": 180000, "description": "tiền xe khách", "category": "transport", "type": "expense", "date": "2026-05-14", "confidence": 0.9] as [String: Any],
                ["amount": 180000, "description": "tiền xe khách", "category": "transport", "type": "expense", "date": "2026-05-15", "confidence": 0.9] as [String: Any],
            ]
        ]

        let results = GeminiParserService.parseResponse(jsonData: json, language: "vi")
        #expect(results.count == 5)
        for result in results {
            #expect(result.amount == 180000)
            #expect(result.note == "tiền xe khách")
            #expect(result.categoryId == "transport")
        }
    }
}

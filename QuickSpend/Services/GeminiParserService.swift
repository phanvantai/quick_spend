import Foundation

/// Parsed transaction result from Gemini AI
struct ParsedTransaction: Identifiable {
    let id = UUID().uuidString
    var amount: Double
    var note: String
    var categoryId: String
    var type: TransactionType
    var date: Date
    var confidence: Double
}

/// AI-powered expense parser using Firebase AI (Gemini)
/// NOTE: Requires FirebaseAI SDK added via SPM. Until then, this service
/// will report as unavailable and the app will fall back to manual input.
enum GeminiParserService {

    /// Whether the Gemini parser is available
    /// Returns true only when Firebase AI SDK is configured
    static var isAvailable: Bool {
        #if canImport(FirebaseAI)
        return _model != nil
        #else
        return false
        #endif
    }

    /// Initialize the Gemini model
    /// Call this from QuickSpendApp after Firebase.configure()
    static func initialize() {
        #if canImport(FirebaseAI)
        _initializeFirebaseModel()
        #else
        print("[GeminiParser] Firebase AI SDK not available. Add firebase-ios-sdk via SPM to enable AI parsing.")
        #endif
    }

    /// Parse transaction from text input using Gemini AI
    static func parse(
        input: String,
        categories: [Category],
        language: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        // Validate input
        guard isValidInput(input) else {
            print("[GeminiParser] Input validation failed")
            return []
        }

        // Check usage limit
        guard usageLimitService.canParse else {
            print("[GeminiParser] Daily limit reached")
            return []
        }

        #if canImport(FirebaseAI)
        return await _parseWithFirebase(
            input: input,
            categories: categories,
            language: language,
            usageLimitService: usageLimitService
        )
        #else
        print("[GeminiParser] Firebase AI not available, cannot parse")
        return []
        #endif
    }

    // MARK: - Input Validation

    static func isValidInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { return false }
        if trimmed.count < AppConstants.minVoiceInputLength { return false }

        // Must contain alphanumeric
        let alphanumeric = CharacterSet.alphanumerics
        if trimmed.unicodeScalars.allSatisfy({ !alphanumeric.contains($0) }) {
            return false
        }

        // Filter filler words
        let fillerPatterns = [
            "^(uh+|um+|ah+|er+|hmm+)$",
            "^(ờ+|à+|ư+|ừ+|ơ+)$",
        ]
        let lowered = trimmed.lowercased()
        for pattern in fillerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil {
                return false
            }
        }

        // Check suspicious repetition (same word 3+ times)
        let words = lowered.split(separator: " ")
        if words.count >= 3 {
            let unique = Set(words)
            if unique.count == 1 { return false }
        }

        return true
    }

    // MARK: - Prompt Building

    static func buildPrompt(input: String, categories: [Category], language: String) -> String {
        let now = Date.now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let currentDate = formatter.string(from: now)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let currentWeekday = weekdayFormatter.string(from: now)

        let incomeCategories = categories.filter(\.isIncomeCategory)
        let expenseCategories = categories.filter(\.isExpenseCategory)

        let incomeCatDesc = incomeCategories.map { cat in
            "  - \(cat.id): \(cat.name)"
        }.joined(separator: "\n")

        let expenseCatDesc = expenseCategories.map { cat in
            "  - \(cat.id): \(cat.name)"
        }.joined(separator: "\n")

        let languageHint: String
        let examples: String

        switch language {
        case "vi":
            languageHint = "User is speaking in Vietnamese. Expect Vietnamese descriptions and slang."
            examples = """
            Examples:
            "45 ca tiền cơm" → {"language":"vi","expenses":[{"amount":45000,"description":"tiền cơm","category":"food_drink","type":"expense","date":"today","confidence":0.95}]}
            "nhận lương 15 triệu" → {"language":"vi","expenses":[{"amount":15000000,"description":"lương","category":"salary","type":"income","date":"today","confidence":0.95}]}
            """
        case "ja":
            languageHint = "User is speaking in Japanese. Expect Japanese descriptions."
            examples = """
            Examples:
            "コーヒー500円" → {"language":"ja","expenses":[{"amount":500,"description":"コーヒー","category":"food_drink","type":"expense","date":"today","confidence":0.95}]}
            "給料25万円" → {"language":"ja","expenses":[{"amount":250000,"description":"給料","category":"salary","type":"income","date":"today","confidence":0.95}]}
            """
        case "es":
            languageHint = "User is speaking in Spanish. Expect Spanish descriptions."
            examples = """
            Examples:
            "café 5 euros" → {"language":"es","expenses":[{"amount":5,"description":"café","category":"food_drink","type":"expense","date":"today","confidence":0.95}]}
            "salario 2000 euros" → {"language":"es","expenses":[{"amount":2000,"description":"salario","category":"salary","type":"income","date":"today","confidence":0.95}]}
            """
        default:
            languageHint = "User is speaking in English. Expect English descriptions."
            examples = """
            Examples:
            "50k coffee" → {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food_drink","type":"expense","date":"today","confidence":0.95}]}
            "received salary 1.5 million" → {"language":"en","expenses":[{"amount":1500000,"description":"salary","category":"salary","type":"income","date":"today","confidence":0.95}]}
            """
        }

        return """
        You are a financial transaction extraction assistant. Extract expense OR income information from user input.

        Input: "\(input)"
        Context: \(languageHint)

        **CURRENT DATE CONTEXT:**
        - Today is: \(currentDate) (\(currentWeekday))
        - Use this to calculate all relative dates accurately

        Rules:
        1. Extract ALL transactions (can be multiple per input)
        2. Classify as EXPENSE or INCOME (income keywords: "received/nhận/lương/給料/受け取り/salario/ingreso", default = expense)
        3. Parse amounts: "50k"=50000, "1m5"=1500000, Vietnamese "ca"=thousand/"củ/cọc"=million, Japanese "万"=10000, "千"=1000
        4. Parse dates: Use CURRENT DATE CONTEXT. Return YYYY-MM-DD format only
        5. Categorize using categories below (match keywords, fallback to "other" or "other_income")
        6. Fix voice errors: "tiền cơ"→"tiền cơm", "xă"→"xăng"
        7. Multiple transactions: "50k coffee and 30k parking" = 2 separate expenses

        Categories:
        INCOME Categories:
        \(incomeCatDesc)

        EXPENSE Categories:
        \(expenseCatDesc)

        Return JSON in this EXACT format:
        {
          "language": "\(language)",
          "expenses": [
            {
              "amount": number,
              "description": "clear description",
              "category": "category_id from the list above",
              "type": "expense" or "income",
              "date": "YYYY-MM-DD",
              "confidence": number between 0 and 1
            }
          ]
        }

        \(examples)

        Now extract from the input above. Return ONLY valid JSON, no other text.
        """
    }

    // MARK: - Response Parsing

    static func parseResponse(jsonData: [String: Any], language: String) -> [ParsedTransaction] {
        guard let expenses = jsonData["expenses"] as? [[String: Any]] else { return [] }

        var results: [ParsedTransaction] = []
        for expenseData in expenses {
            guard let amount = (expenseData["amount"] as? NSNumber)?.doubleValue, amount > 0 else { continue }

            let description = expenseData["description"] as? String ?? ""
            let categoryStr = (expenseData["category"] as? String ?? "other").lowercased()
            let typeStr = (expenseData["type"] as? String ?? "expense").lowercased()
            let dateStr = expenseData["date"] as? String ?? "today"
            let confidence = (expenseData["confidence"] as? NSNumber)?.doubleValue ?? 0.5

            let type = typeStr == "income" ? TransactionType.income : TransactionType.expense
            let categoryId = normalizeCategoryId(categoryStr, type: type)
            let correctedType = typeFromCategory(categoryId)
            let date = parseDate(dateStr)

            results.append(ParsedTransaction(
                amount: amount,
                note: description.isEmpty ? (correctedType == .income ? "Income" : "Expense") : description,
                categoryId: categoryId,
                type: correctedType,
                date: date,
                confidence: confidence
            ))
        }
        return results
    }

    // MARK: - Helpers

    private static func normalizeCategoryId(_ categoryStr: String, type: TransactionType) -> String {
        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        let expenseCategories: Set<String> = ["food_drink", "groceries", "transport", "housing", "bills_utilities", "shopping", "health", "education", "entertainment", "personal_care", "gifts", "family", "insurance", "savings_invest", "debt_payment", "pets", "travel", "other_expense"]

        if type == .income {
            return incomeCategories.contains(categoryStr) ? categoryStr : "other_income"
        } else {
            return expenseCategories.contains(categoryStr) ? categoryStr : "other_expense"
        }
    }

    private static func typeFromCategory(_ categoryId: String) -> TransactionType {
        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        return incomeCategories.contains(categoryId) ? .income : .expense
    }

    private static func parseDate(_ dateStr: String) -> Date {
        let now = Date.now
        let calendar = Calendar.current
        let normalized = dateStr.lowercased().trimmingCharacters(in: .whitespaces)

        if normalized == "today" || normalized == "hôm nay" {
            return calendar.startOfDay(for: now)
        }
        if normalized == "yesterday" || normalized == "hôm qua" {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
        }

        // Try ISO date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: normalized) {
            return calendar.startOfDay(for: parsed)
        }

        return calendar.startOfDay(for: now)
    }
}

// MARK: - Firebase AI Integration
// This section compiles only when FirebaseAI SDK is available

#if canImport(FirebaseAI)
import FirebaseAI

private var _model: GenerativeModel?

extension GeminiParserService {
    static func _initializeFirebaseModel() {
        do {
            _model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
                modelName: "gemini-2.5-flash",
                generationConfig: GenerationConfig(
                    temperature: 0.1,
                    topP: 1,
                    topK: 1,
                    maxOutputTokens: 1024,
                    responseMIMEType: "application/json"
                )
            )
            print("[GeminiParser] Initialized with Gemini 2.5 Flash via Firebase AI")
        } catch {
            print("[GeminiParser] Failed to initialize: \(error)")
            _model = nil
        }
    }

    static func _parseWithFirebase(
        input: String,
        categories: [Category],
        language: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        guard let model = _model else { return [] }

        let prompt = buildPrompt(input: input, categories: categories, language: language)

        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text, !text.isEmpty else {
                print("[GeminiParser] Empty response")
                return []
            }

            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[GeminiParser] Invalid JSON response")
                return []
            }

            let results = parseResponse(jsonData: json, language: language)
            if !results.isEmpty {
                usageLimitService.incrementUsage()
            }
            return results
        } catch {
            print("[GeminiParser] Error: \(error)")
            return []
        }
    }
}
#endif

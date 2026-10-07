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
    var rawInput: String?
}

/// AI-powered expense parser using Firebase AI (Gemini)
/// NOTE: Requires FirebaseAILogic SDK added via SPM. Until then, this service
/// will report as unavailable and the app will fall back to manual input.
enum GeminiParserService {

    /// Whether the Gemini parser is available
    /// Returns true only when Firebase AI SDK is configured
    static var isAvailable: Bool {
        #if canImport(FirebaseAILogic)
        return _firebaseAI != nil
        #else
        return false
        #endif
    }

    /// Initialize the Gemini model
    /// Call this from QuickSpendApp after Firebase.configure()
    static func initialize() {
        #if canImport(FirebaseAILogic)
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
        currency: String = "USD",
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

        #if canImport(FirebaseAILogic)
        return await _parseWithFirebase(
            input: input,
            categories: categories,
            language: language,
            currency: currency,
            usageLimitService: usageLimitService
        )
        #else
        print("[GeminiParser] Firebase AI not available, cannot parse")
        return []
        #endif
    }

    // MARK: - Cached Regex Patterns

    private static let fillerRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^(uh+|um+|ah+|er+|hmm+)$", options: .caseInsensitive),
        try! NSRegularExpression(pattern: "^(ờ+|à+|ư+|ừ+|ơ+)$", options: .caseInsensitive),
    ]

    private static let daysAgoRegexes: [(NSRegularExpression, Int)] = {
        let patterns = [
            #"(\d+)\s*days?\s*ago"#,
            #"(\d+)\s*ngày\s*trước"#,
            #"cách\s*đây\s*(\d+)\s*ngày"#,
            #"hace\s*(\d+)\s*días?"#,
        ]
        return patterns.compactMap { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (regex, 1)
        }
    }()

    // MARK: - Input Validation

    static func isValidInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            print("[GeminiParser] Rejected: empty input")
            return false
        }
        if trimmed.count < AppConstants.minVoiceInputLength {
            print("[GeminiParser] Rejected: too short (\(trimmed.count) chars, min \(AppConstants.minVoiceInputLength)): \"\(trimmed)\"")
            return false
        }
        if trimmed.count > AppConstants.maxVoiceInputLength {
            print("[GeminiParser] Rejected: too long (\(trimmed.count) chars, max \(AppConstants.maxVoiceInputLength)): \"\(trimmed.prefix(50))...\"")
            return false
        }

        // Must contain alphanumeric
        let alphanumeric = CharacterSet.alphanumerics
        if trimmed.unicodeScalars.allSatisfy({ !alphanumeric.contains($0) }) {
            print("[GeminiParser] Rejected: no alphanumeric characters: \"\(trimmed)\"")
            return false
        }

        // Must contain at least one letter (pure numbers have no expense context)
        let letters = CharacterSet.letters
        if !trimmed.unicodeScalars.contains(where: { letters.contains($0) }) {
            print("[GeminiParser] Rejected: no letters (pure numbers/symbols): \"\(trimmed)\"")
            return false
        }

        // Filter filler words using cached regex
        let lowered = trimmed.lowercased()
        for regex in fillerRegexes {
            if regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil {
                print("[GeminiParser] Rejected: filler word detected: \"\(trimmed)\"")
                return false
            }
        }

        // Check suspicious repetition (same word 3+ times)
        let words = lowered.split(separator: " ")
        if words.count >= 3 {
            let unique = Set(words)
            if unique.count == 1 {
                print("[GeminiParser] Rejected: repeated word (\(words.count)x \"\(words[0])\"): \"\(trimmed)\"")
                return false
            }
        }

        print("[GeminiParser] Input validated: \"\(trimmed)\" (\(trimmed.count) chars, \(words.count) words)")
        return true
    }

    // MARK: - Instructions

    /// Fallback category IDs the model may always use, even if the user removed them
    static let fallbackCategoryIds = ["other_expense", "other_income"]

    /// System instruction for the model: our app's data plus the product rules
    /// the model cannot guess. Language understanding is left to the model.
    static func buildInstructions(categories: [Category], language: String, currency: String = "USD", now: Date = .now) -> String {
        // POSIX + Gregorian so the model always sees e.g. "2026-03-04 (Wednesday)",
        // even when the device uses the Japanese or Buddhist calendar
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: now)

        let expenseList = categories.filter(\.isExpenseCategory)
            .map { "- \($0.id): \($0.name)" }
            .joined(separator: "\n")
        let incomeList = categories.filter(\.isIncomeCategory)
            .map { "- \($0.id): \($0.name)" }
            .joined(separator: "\n")

        return """
        You turn what a user said into transactions for an expense-tracking app. \
        The text comes from speech recognition, so it may contain recognition errors, slang, or mixed languages.

        Context:
        - Today: \(today) (\(weekday))
        - Currency: \(currency). Return amounts as plain numbers in this currency (for example "50k" → 50000).
        - App language: \(languageName(for: language)). Write each description in the language the user spoke, in a few words.

        Expense categories:
        \(expenseList)

        Income categories:
        \(incomeList)

        Rules:
        - Return one transaction per item mentioned. A date range with "each day" means one transaction per day in that range, each with its own date.
        - The type is "expense" unless the user clearly received money.
        - Pick the closest category of the matching type. Use other_expense or other_income if none fits.
        - Dates are YYYY-MM-DD. Use today if no date is mentioned.
        - confidence (0 to 1): use 0.9 or higher only when the amount, date, and category are all clear. Use less than 0.7 if you had to guess any of them.
        - If the text is not about money, return an empty list.
        """
    }

    /// Category IDs the response schema allows: the user's categories in order, plus fallbacks
    static func allowedCategoryIds(for categories: [Category]) -> [String] {
        var ids = categories.map(\.id)
        for fallback in fallbackCategoryIds where !ids.contains(fallback) {
            ids.append(fallback)
        }
        return ids
    }

    private static func languageName(for code: String) -> String {
        switch code {
        case "vi": return "Vietnamese"
        case "ja": return "Japanese"
        case "es": return "Spanish"
        default: return "English"
        }
    }

    // MARK: - Response Parsing

    static func parseResponse(jsonData: [String: Any], language: String, validCategoryIds: Set<String> = []) -> [ParsedTransaction] {
        guard let expenses = jsonData["expenses"] as? [[String: Any]] else {
            print("[GeminiParser] Response has no 'expenses' array")
            return []
        }

        print("[GeminiParser] Response: \(expenses.count) expense(s) in JSON")

        var results: [ParsedTransaction] = []
        for (index, expenseData) in expenses.enumerated() {
            guard let amount = (expenseData["amount"] as? NSNumber)?.doubleValue, amount > 0 else {
                let rawAmount = expenseData["amount"]
                print("[GeminiParser] Skipped expense[\(index)]: invalid amount (\(String(describing: rawAmount)))")
                continue
            }

            // Clamp amount to max allowed
            let clampedAmount = min(amount, AppConstants.maxExpenseAmount)

            let description = expenseData["description"] as? String ?? ""
            let categoryStr = (expenseData["category"] as? String ?? "other").lowercased()
            let typeStr = (expenseData["type"] as? String ?? "expense").lowercased()
            let dateStr = expenseData["date"] as? String ?? "today"
            let confidence = (expenseData["confidence"] as? NSNumber)?.doubleValue ?? 0.5

            let type = typeStr == "income" ? TransactionType.income : TransactionType.expense
            let categoryId = normalizeCategoryId(categoryStr, type: type, validCategoryIds: validCategoryIds)
            let correctedType = typeFromCategory(categoryId)
            let date = parseDate(dateStr)

            results.append(ParsedTransaction(
                amount: clampedAmount,
                note: description.isEmpty ? (correctedType == .income ? "Income" : "Expense") : description,
                categoryId: categoryId,
                type: correctedType,
                date: date,
                confidence: confidence
            ))
        }
        if results.isEmpty && !expenses.isEmpty {
            print("[GeminiParser] All \(expenses.count) expense(s) were filtered out (invalid amounts)")
        }
        return results
    }

    // MARK: - Helpers

    static func normalizeCategoryId(_ categoryStr: String, type: TransactionType, validCategoryIds: Set<String> = []) -> String {
        // Accept any category ID that exists in the actual categories list
        if !validCategoryIds.isEmpty && validCategoryIds.contains(categoryStr) {
            return categoryStr
        }

        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        let expenseCategories: Set<String> = ["food_drink", "groceries", "transport", "housing", "bills_utilities", "shopping", "health", "education", "entertainment", "personal_care", "gifts", "family", "insurance", "savings_invest", "debt_payment", "pets", "travel", "other_expense"]

        if type == .income {
            return incomeCategories.contains(categoryStr) ? categoryStr : "other_income"
        } else {
            return expenseCategories.contains(categoryStr) ? categoryStr : "other_expense"
        }
    }

    static func typeFromCategory(_ categoryId: String) -> TransactionType {
        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        return incomeCategories.contains(categoryId) ? .income : .expense
    }

    static func parseDate(_ dateStr: String) -> Date {
        let now = Date.now
        let calendar = Calendar.current
        let normalized = dateStr.lowercased().trimmingCharacters(in: .whitespaces)

        let todayWords: Set<String> = ["today", "hôm nay", "今日", "hoy"]
        let yesterdayWords: Set<String> = ["yesterday", "hôm qua", "昨日", "ayer"]
        let dayBeforeYesterdayWords: Set<String> = ["day before yesterday", "hôm kia", "一昨日", "おととい", "anteayer", "antes de ayer"]

        if todayWords.contains(normalized) {
            return calendar.startOfDay(for: now)
        }
        if yesterdayWords.contains(normalized) {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
        }
        if dayBeforeYesterdayWords.contains(normalized) {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: now)!)
        }

        // Handle "N days ago" patterns (English, Vietnamese, Japanese, Spanish)
        if let daysAgo = parseDaysAgo(normalized) {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        // Try ISO date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: normalized) {
            // Validate the date is not unreasonably far in the past or future
            let yearsFromNow = calendar.dateComponents([.year], from: parsed, to: now).year ?? 0
            if abs(yearsFromNow) <= AppConstants.maxYearsInPast {
                return calendar.startOfDay(for: parsed)
            }
        }

        return calendar.startOfDay(for: now)
    }

    /// Parse "N days ago" patterns in multiple languages
    static func parseDaysAgo(_ text: String) -> Int? {
        for (regex, _) in daysAgoRegexes {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                for i in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: i), in: text),
                       let days = Int(text[range]), days > 0 && days <= 365 {
                        return days
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - Firebase AI Integration
// This section compiles only when FirebaseAILogic SDK is available

#if canImport(FirebaseAILogic)
import FirebaseAILogic

private var _firebaseAI: FirebaseAI?

extension GeminiParserService {
    static func _initializeFirebaseModel() {
        _firebaseAI = FirebaseAI.firebaseAI(backend: .googleAI())
        print("[GeminiParser] Initialized with \(AppConstants.geminiModelName) via Firebase AI")
    }

    /// Builds a model per request, since the instructions and the allowed
    /// category IDs depend on the user's categories, language, and currency.
    static func _makeModel(ai: FirebaseAI, categories: [Category], language: String, currency: String) -> GenerativeModel {
        ai.generativeModel(
            modelName: AppConstants.geminiModelName,
            // Gemini 3.x: keep default temperature (lower values can cause looping)
            // and use low thinking, since parsing doesn't need deep reasoning.
            // Thinking tokens count toward maxOutputTokens, so leave headroom
            // for long date ranges (one transaction per day).
            generationConfig: GenerationConfig(
                maxOutputTokens: 4096,
                responseMIMEType: "application/json",
                responseSchema: _responseSchema(categoryIds: allowedCategoryIds(for: categories)),
                thinkingConfig: ThinkingConfig(thinkingLevel: .low)
            ),
            systemInstruction: ModelContent(role: "system", parts: buildInstructions(
                categories: categories,
                language: language,
                currency: currency
            ))
        )
    }

    /// The response shape that `parseResponse` reads. The category must be one
    /// of the user's category IDs, so the model cannot invent one.
    static func _responseSchema(categoryIds: [String]) -> Schema {
        .object(properties: [
            "expenses": .array(items: .object(properties: [
                "amount": .double(description: "Positive amount in the user's currency"),
                "description": .string(description: "A few words, in the language the user spoke"),
                "category": .enumeration(values: categoryIds),
                "type": .enumeration(values: ["expense", "income"]),
                "date": .string(description: "YYYY-MM-DD"),
                "confidence": .double(description: "0 to 1"),
            ])),
        ])
    }

    static func _parseWithFirebase(
        input: String,
        categories: [Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        guard let ai = _firebaseAI else { return [] }

        let model = _makeModel(ai: ai, categories: categories, language: language, currency: currency)
        let validCategoryIds = Set(categories.map(\.id))

        do {
            let response = try await withThrowingTaskGroup(of: GenerateContentResponse.self) { group in
                group.addTask {
                    try await model.generateContent(input)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(AppConstants.geminiApiTimeoutSeconds))
                    throw GeminiTimeoutError()
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            guard let text = response.text, !text.isEmpty else {
                print("[GeminiParser] Empty response from Gemini")
                return []
            }

            print("[GeminiParser] Raw Gemini response: \(text)")

            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[GeminiParser] Failed to parse JSON from response")
                return []
            }

            let results = parseResponse(jsonData: json, language: language, validCategoryIds: validCategoryIds)
            if !results.isEmpty {
                usageLimitService.incrementUsage()
                print("[GeminiParser] Successfully parsed \(results.count) transaction(s), usage incremented")
            } else {
                print("[GeminiParser] No valid transactions extracted from response")
            }
            return results
        } catch is GeminiTimeoutError {
            print("[GeminiParser] Gemini API timed out after \(AppConstants.geminiApiTimeoutSeconds)s")
            return []
        } catch {
            print("[GeminiParser] Error calling Gemini: \(error)")
            return []
        }
    }
}

private struct GeminiTimeoutError: Error {}

#endif

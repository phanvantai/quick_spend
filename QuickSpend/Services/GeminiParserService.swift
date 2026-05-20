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

        #if canImport(FirebaseAI)
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

    // MARK: - Prompt Building

    static func buildPrompt(input: String, categories: [Category], language: String, currency: String = "USD") -> String {
        let now = Date.now
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let currentDate = formatter.string(from: now)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let currentWeekday = weekdayFormatter.string(from: now)

        let weekdayNumber = calendar.component(.weekday, from: now)

        let thisMonday = calendar.date(byAdding: .day, value: -(weekdayNumber == 1 ? 6 : weekdayNumber - 2), to: now)!
        let lastMonday = calendar.date(byAdding: .day, value: -7, to: thisMonday)!
        let lastFriday = calendar.date(byAdding: .day, value: 4, to: lastMonday)!
        let lastSunday = calendar.date(byAdding: .day, value: 6, to: lastMonday)!

        let calendarContext = """
        - Today is: \(currentDate) (\(currentWeekday))
        - This week's Monday: \(formatter.string(from: thisMonday))
        - Last week: \(formatter.string(from: lastMonday)) (Mon) to \(formatter.string(from: lastSunday)) (Sun)
        - Last week's Friday: \(formatter.string(from: lastFriday))
        """

        let incomeCategories = categories.filter(\.isIncomeCategory)
        let expenseCategories = categories.filter(\.isExpenseCategory)

        let incomeCatDesc = incomeCategories.map { cat in
            "  - \(cat.id): \(cat.name)"
        }.joined(separator: "\n")

        let expenseCatDesc = expenseCategories.map { cat in
            "  - \(cat.id): \(cat.name)"
        }.joined(separator: "\n")

        let languageHint: String
        let languageSpecificRules: String
        let examples: String

        switch language {
        case "vi":
            languageHint = "Expected language: Vietnamese. However, the input may contain other languages — auto-detect and parse accordingly."
            languageSpecificRules = """
            **Vietnamese-specific rules:**
            - Amount abbreviations: "ca"/"k"=thousand (×1,000), "củ"/"cọc"/"triệu"=million (×1,000,000), "1m5"=1,500,000
            - Income keywords: nhận, lương, thưởng, thu nhập
            - Fix common voice recognition errors: "tiền cơ"→"tiền cơm", "xă"→"xăng", "gửi xe"→"gửi xe"
            - **Weekday names:** thứ 2/thứ hai=Monday, thứ 3/thứ ba=Tuesday, thứ 4/thứ tư=Wednesday, thứ 5/thứ năm=Thursday, thứ 6/thứ sáu=Friday, thứ 7/thứ bảy=Saturday, chủ nhật=Sunday
            - **Relative dates:** "hôm nay"=today, "hôm qua"=yesterday, "hôm kia"=day before yesterday
            - **Relative weeks:** "tuần trước"/"tuần rồi"=last week, "tuần này"=this week, "tuần sau"=next week
            - **Relative months:** "tháng trước"/"tháng rồi"=last month, "tháng này"=this month
            - **Date ranges:** "thứ 2 đến thứ 6"=Monday to Friday, "từ ngày X đến ngày Y"=from day X to day Y
            - **Repetition:** "mỗi ngày"=each day (create one transaction per day in range), "hàng ngày"=daily
            """
            examples = """
            Examples:
            "45 ca tiền cơm" → amount=45000, description="tiền cơm", category="food_drink", type="expense", date=today
            "nhận lương 15 triệu" → amount=15000000, description="lương", category="salary", type="income", date=today
            "thứ 2 đến thứ 6 tuần trước mỗi ngày 180000 tiền xe khách" → 5 separate expenses, one per day (Mon-Fri of last week), each amount=180000, description="tiền xe khách", category="transport"
            "tuần trước thứ 4 ăn phở 60 nghìn" → amount=60000, description="ăn phở", category="food_drink", date=last Wednesday
            "3 ngày trước cafe 35k" → amount=35000, description="cafe", category="food_drink", date=3 days ago
            """
        case "ja":
            languageHint = "Expected language: Japanese. However, the input may contain other languages — auto-detect and parse accordingly."
            languageSpecificRules = """
            **Japanese-specific rules:**
            - Amount units: "万"(man)=×10,000, "千"(sen)=×1,000, "億"(oku)=×100,000,000
            - Income keywords: 給料, 受け取り, ボーナス, 収入
            - **Weekday names:** 月曜日=Monday, 火曜日=Tuesday, 水曜日=Wednesday, 木曜日=Thursday, 金曜日=Friday, 土曜日=Saturday, 日曜日=Sunday
            - **Relative dates:** "今日"=today, "昨日"=yesterday, "一昨日"=day before yesterday
            - **Relative weeks:** "先週"=last week, "今週"=this week, "来週"=next week
            - **Relative months:** "先月"=last month, "今月"=this month
            - **Date ranges:** "月曜から金曜"=Monday to Friday
            - **Repetition:** "毎日"=each day (create one transaction per day in range)
            """
            examples = """
            Examples:
            "コーヒー500円" → amount=500, description="コーヒー", category="food_drink", type="expense"
            "給料25万円" → amount=250000, description="給料", category="salary", type="income"
            "先週月曜から金曜まで毎日交通費500円" → 5 separate expenses (Mon-Fri last week), each amount=500, description="交通費", category="transport"
            """
        case "es":
            languageHint = "Expected language: Spanish. However, the input may contain other languages — auto-detect and parse accordingly."
            languageSpecificRules = """
            **Spanish-specific rules:**
            - Amount format: period for thousands (1.000), comma for decimals (1,50)
            - Income keywords: salario, ingreso, recibido, sueldo, nómina
            - **Weekday names:** lunes=Monday, martes=Tuesday, miércoles=Wednesday, jueves=Thursday, viernes=Friday, sábado=Saturday, domingo=Sunday
            - **Relative dates:** "hoy"=today, "ayer"=yesterday, "anteayer"=day before yesterday
            - **Relative weeks:** "la semana pasada"=last week, "esta semana"=this week
            - **Relative months:** "el mes pasado"=last month, "este mes"=this month
            - **Date ranges:** "de lunes a viernes"=Monday to Friday
            - **Repetition:** "cada día"/"todos los días"=each day (create one transaction per day in range)
            """
            examples = """
            Examples:
            "café 5 euros" → amount=5, description="café", category="food_drink", type="expense"
            "salario 2000 euros" → amount=2000, description="salario", category="salary", type="income"
            "la semana pasada de lunes a viernes transporte 3 euros cada día" → 5 separate expenses (Mon-Fri last week), each amount=3, description="transporte", category="transport"
            """
        default:
            languageHint = "Expected language: English. However, the input may contain other languages — auto-detect and parse accordingly."
            languageSpecificRules = """
            **English-specific rules:**
            - Amount abbreviations: "k"=×1,000, "m"=×1,000,000
            - Income keywords: received, salary, earned, paid, income
            - **Weekday names:** Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday
            - **Relative dates:** "today", "yesterday", "day before yesterday"
            - **Relative weeks:** "last week", "this week", "next week"
            - **Relative months:** "last month", "this month"
            - **Date ranges:** "Monday to Friday", "from X to Y"
            - **Repetition:** "every day"/"each day"/"daily" (create one transaction per day in range)
            """
            examples = """
            Examples:
            "50k coffee" → amount=50000, description="coffee", category="food_drink", type="expense"
            "received salary 1.5 million" → amount=1500000, description="salary", category="salary", type="income"
            "last week Monday to Friday 20 dollars each day for lunch" → 5 separate expenses (Mon-Fri last week), each amount=20, description="lunch", category="food_drink"
            """
        }

        return """
        You are a financial transaction extraction assistant. Extract expense OR income information from user input.

        Input: "\(input)"
        Context: \(languageHint)

        **CURRENCY CONTEXT:**
        - User's currency: \(currency)
        - Interpret amounts in this currency context (e.g., "50k" in VND = 50,000 VND for a coffee, "50k" in USD = $50,000)

        **CURRENT DATE CONTEXT (use for all date calculations):**
        \(calendarContext)
        - Use these dates to resolve weekday names, "last week", "this week", etc.

        **GENERAL RULES:**
        1. First, auto-detect the actual language of the input. It may differ from the expected language.
        2. Extract ALL transactions (can be multiple per input).
        3. Classify as EXPENSE or INCOME (default = expense).
        4. Parse dates: Return YYYY-MM-DD format only. Use CURRENT DATE CONTEXT for relative dates.
        5. Categorize using the categories listed below (match keywords, fallback to "other_expense" or "other_income").
        6. Multiple transactions: "50k coffee and 30k parking" = 2 separate expenses.
        7. If the input language doesn't match the expected language, still parse correctly. Set "detected_language" to the actual language code.
        8. **Date ranges with repetition:** When the user specifies a date range (e.g., "Monday to Friday") combined with "each day"/"every day"/"mỗi ngày"/"毎日"/"cada día", create ONE SEPARATE TRANSACTION for EACH day in that range with the SAME amount and description. Each transaction gets its own correct date.
        9. **Relative weekday resolution:** "last Monday" or "thứ 2 tuần trước" = the Monday of last week. Use the CURRENT DATE CONTEXT to calculate the exact YYYY-MM-DD.
        10. **Always produce output.** If you can extract any amount + description, return it. Only return empty expenses array if the input is truly unrelated to finances.

        \(languageSpecificRules)

        **CATEGORIES:**
        INCOME:
        \(incomeCatDesc)

        EXPENSE:
        \(expenseCatDesc)

        Return JSON in this EXACT format:
        {
          "detected_language": "actual language code (en/vi/ja/es)",
          "expenses": [
            {
              "amount": number,
              "description": "clear description in the detected language",
              "category": "category_id from the list above",
              "type": "expense" or "income",
              "date": "YYYY-MM-DD",
              "confidence": number between 0 and 1 (lower if language mismatch or ambiguous input)
            }
          ]
        }

        \(examples)

        Now extract from the input above. Return ONLY valid JSON, no other text.
        """
    }

    // MARK: - Response Parsing

    static func parseResponse(jsonData: [String: Any], language: String, validCategoryIds: Set<String> = []) -> [ParsedTransaction] {
        let detectedLang = jsonData["detected_language"] as? String ?? "unknown"
        guard let expenses = jsonData["expenses"] as? [[String: Any]] else {
            print("[GeminiParser] Response has no 'expenses' array (detected_language: \(detectedLang))")
            return []
        }

        print("[GeminiParser] Response: \(expenses.count) expense(s) in JSON (detected_language: \(detectedLang))")

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
// This section compiles only when FirebaseAI SDK is available

#if canImport(FirebaseAI)
import FirebaseAI

private var _model: GenerativeModel?

extension GeminiParserService {
    static func _initializeFirebaseModel() {
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
    }

    static func _parseWithFirebase(
        input: String,
        categories: [Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        guard let model = _model else { return [] }

        let prompt = buildPrompt(input: input, categories: categories, language: language, currency: currency)
        let validCategoryIds = Set(categories.map(\.id))

        do {
            let response = try await withThrowingTaskGroup(of: GenerateContentResponse.self) { group in
                group.addTask {
                    try await model.generateContent(prompt)
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

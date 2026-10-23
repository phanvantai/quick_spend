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
    /// Wallet the money left or arrived in. `nil` means the default wallet.
    var walletId: String?
    /// Set for a transfer between two of the user's wallets (`walletId` is the
    /// source). Empty when the model could not tell the destination.
    var transferToWalletId: String?

    var isTransfer: Bool { transferToWalletId != nil }

    /// A transfer that cannot be saved as-is: no valid destination, or the
    /// destination is the source wallet.
    var isIncompleteTransfer: Bool {
        guard let destination = transferToWalletId else { return false }
        return destination.isEmpty || destination == walletId
    }
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
        wallets: [Wallet] = [],
        defaultWalletId: String = Wallet.personalID,
        currency: String = "USD",
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        // Validate input
        guard isValidInput(input) else {
            print("[GeminiParser] Input validation failed")
            AnalyticsService.logGeminiParseFailed(errorReason: "invalid_input", language: language)
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
            wallets: wallets,
            defaultWalletId: defaultWalletId,
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
            #if DEBUG
            print("[GeminiParser] Rejected: too short (\(trimmed.count) chars, min \(AppConstants.minVoiceInputLength)): \"\(trimmed)\"")
            #endif
            return false
        }
        if trimmed.count > AppConstants.maxVoiceInputLength {
            #if DEBUG
            print("[GeminiParser] Rejected: too long (\(trimmed.count) chars, max \(AppConstants.maxVoiceInputLength)): \"\(trimmed.prefix(50))...\"")
            #endif
            return false
        }

        // Must contain alphanumeric
        let alphanumeric = CharacterSet.alphanumerics
        if trimmed.unicodeScalars.allSatisfy({ !alphanumeric.contains($0) }) {
            #if DEBUG
            print("[GeminiParser] Rejected: no alphanumeric characters: \"\(trimmed)\"")
            #endif
            return false
        }

        // Must contain at least one letter (pure numbers have no expense context)
        let letters = CharacterSet.letters
        if !trimmed.unicodeScalars.contains(where: { letters.contains($0) }) {
            #if DEBUG
            print("[GeminiParser] Rejected: no letters (pure numbers/symbols): \"\(trimmed)\"")
            #endif
            return false
        }

        // Filter filler words using cached regex
        let lowered = trimmed.lowercased()
        for regex in fillerRegexes {
            if regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil {
                #if DEBUG
                print("[GeminiParser] Rejected: filler word detected: \"\(trimmed)\"")
                #endif
                return false
            }
        }

        // Check suspicious repetition (same word 3+ times)
        let words = lowered.split(separator: " ")
        if words.count >= 3 {
            let unique = Set(words)
            if unique.count == 1 {
                #if DEBUG
                print("[GeminiParser] Rejected: repeated word (\(words.count)x \"\(words[0])\"): \"\(trimmed)\"")
                #endif
                return false
            }
        }

        #if DEBUG
        print("[GeminiParser] Input validated: \"\(trimmed)\" (\(trimmed.count) chars, \(words.count) words)")
        #endif
        return true
    }

    // MARK: - Instructions

    /// Fallback category IDs the model may always use, even if the user removed them
    static let fallbackCategoryIds = ["other_expense", "other_income"]

    /// Confidence given to a result the app does not trust enough to save
    /// without review: a fallback category, a future date, or a transfer whose
    /// wallets are unclear. Below `AppConstants.confidenceWarningThreshold`, so
    /// the review screen also flags it.
    static let uncertainConfidence = 0.6

    /// System instruction for the model: our app's data plus the product rules
    /// the model cannot guess. Language understanding is left to the model.
    static func buildInstructions(
        categories: [Category],
        wallets: [Wallet] = [],
        defaultWalletId: String? = nil,
        language: String,
        currency: String = "USD",
        now: Date = .now
    ) -> String {
        // POSIX + Gregorian so the model always sees e.g. "2026-03-04 (Wednesday)",
        // even when the device uses the Japanese or Buddhist calendar
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: now)

        let visible = categories.filter { !$0.isHidden }
        let expenseList = visible.filter(\.isExpenseCategory)
            .map { "- \($0.id): \($0.name)" }
            .joined(separator: "\n")
        let incomeList = visible.filter(\.isIncomeCategory)
            .map { "- \($0.id): \($0.name)" }
            .joined(separator: "\n")
        let walletSection = walletInstructions(
            wallets: activeWallets(wallets),
            defaultWalletId: defaultWalletId,
            language: language
        )

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
        \(walletSection)
        Rules:
        - Return one transaction per item mentioned. A date range with "each day" means one transaction per day in that range, each with its own date.
        - The type is "expense" unless the user clearly received money.
        - Pick the closest category of the matching type. Use other_expense or other_income if none fits.
        - Dates are YYYY-MM-DD, never after today. Use today if no date is mentioned.
        - confidence (0 to 1): use 0.9 or higher only when the amount, date, and category are all clear. Use less than 0.7 if you had to guess any of them.
        - If the text is not about money, return an empty list.
        """
    }

    /// Wallet list and transfer rules, only when the user has 2+ wallets.
    private static func walletInstructions(wallets: [Wallet], defaultWalletId: String?, language: String) -> String {
        guard wallets.count > 1 else { return "" }
        let defaultId = resolvedDefaultWalletId(wallets: wallets, preferred: defaultWalletId) ?? Wallet.personalID
        let list = wallets
            .map { "- \($0.id): \($0.displayName(language: language))" }
            .joined(separator: "\n")
        return """

        Wallets (default: \(defaultId)):
        \(list)

        Wallet rules:
        - "wallet" is the wallet the money left or arrived in. Set it only when the user names one of these wallets; otherwise leave it out and the default wallet is used.
        - Money moved between two of these wallets (a transfer, withdrawing cash, topping up, putting money into savings) has type "transfer": "wallet" is where it leaves, "to_wallet" is where it arrives, and the category is other_expense. If either wallet is unclear, still return the transfer with confidence below 0.7.

        """
    }

    private static func activeWallets(_ wallets: [Wallet]) -> [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The preferred default if it is an active wallet, else Personal, else the first.
    private static func resolvedDefaultWalletId(wallets: [Wallet], preferred: String?) -> String? {
        let ids = activeWallets(wallets).map(\.id)
        if let preferred, ids.contains(preferred) { return preferred }
        if ids.contains(Wallet.personalID) { return Wallet.personalID }
        return ids.first
    }

    /// Category IDs the response schema allows: the user's categories in order, plus fallbacks
    static func allowedCategoryIds(for categories: [Category]) -> [String] {
        var ids = categories.filter { !$0.isHidden }.map(\.id)
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

    /// Turns the model's JSON into transactions and applies the checks the
    /// model cannot be trusted with: the category's real type, known wallets,
    /// no future dates, and lower confidence for anything the app had to fix.
    static func parseResponse(
        jsonData: [String: Any],
        language: String,
        categories: [Category] = [],
        wallets: [Wallet] = [],
        defaultWalletId: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ParsedTransaction] {
        guard let items = (jsonData["transactions"] ?? jsonData["expenses"]) as? [[String: Any]] else {
            print("[GeminiParser] Response has no 'transactions' array")
            return []
        }

        print("[GeminiParser] Response: \(items.count) transaction(s) in JSON")

        let usableCategories = categories.filter { !$0.isHidden }
        let categoryById = Dictionary(usableCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let validCategoryIds = Set(categoryById.keys)
        let walletIds = Set(activeWallets(wallets).map(\.id))
        let defaultWallet = resolvedDefaultWalletId(wallets: wallets, preferred: defaultWalletId)
        let canTransfer = walletIds.count > 1
        let today = calendar.startOfDay(for: now)

        var results: [ParsedTransaction] = []
        for (index, item) in items.enumerated() {
            guard let amount = (item["amount"] as? NSNumber)?.doubleValue, amount > 0 else {
                #if DEBUG
                print("[GeminiParser] Skipped transaction[\(index)]: invalid amount (\(String(describing: item["amount"])))")
                #endif
                continue
            }
            let clampedAmount = min(amount, AppConstants.maxExpenseAmount)

            let description = (item["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryStr = (item["category"] as? String ?? "other").lowercased()
            let typeStr = (item["type"] as? String ?? "expense").lowercased()
            var confidence = (item["confidence"] as? NSNumber)?.doubleValue ?? 0.5

            var date = parseDate(item["date"] as? String ?? "today", calendar: calendar)
            if date > today {
                date = today
                confidence = min(confidence, uncertainConfidence)
            }

            let namedWallet = (item["wallet"] as? String).flatMap { walletIds.contains($0) ? $0 : nil }
            let walletId = namedWallet ?? defaultWallet

            if typeStr == "transfer" && canTransfer {
                let source = walletId ?? Wallet.personalID
                let destination = (item["to_wallet"] as? String)
                    .flatMap { walletIds.contains($0) && $0 != source ? $0 : nil }
                if destination == nil {
                    confidence = min(confidence, uncertainConfidence)
                }
                results.append(ParsedTransaction(
                    amount: clampedAmount,
                    note: description.isEmpty ? L10n.tr("transfer.title", language) : description,
                    categoryId: Transfer.categoryId,
                    type: .expense,
                    date: date,
                    confidence: confidence,
                    walletId: source,
                    transferToWalletId: destination ?? ""
                ))
                continue
            }
            if typeStr == "transfer" {
                // Nowhere to transfer to: keep it as an expense the user reviews.
                confidence = min(confidence, uncertainConfidence)
            }

            let type: TransactionType = typeStr == "income" ? .income : .expense
            let categoryId = normalizeCategoryId(categoryStr, type: type, validCategoryIds: validCategoryIds)
            let correctedType = typeFromCategory(categoryId, categories: usableCategories)
            if fallbackCategoryIds.contains(categoryId) {
                confidence = min(confidence, uncertainConfidence)
            }

            let defaultNote = categoryById[categoryId]?.name
                ?? L10n.tr(correctedType == .income ? "common.income" : "common.expense", language)
            results.append(ParsedTransaction(
                amount: clampedAmount,
                note: description.isEmpty ? defaultNote : description,
                categoryId: categoryId,
                type: correctedType,
                date: date,
                confidence: confidence,
                walletId: walletId
            ))
        }
        if results.isEmpty && !items.isEmpty {
            print("[GeminiParser] All \(items.count) transaction(s) were filtered out (invalid amounts)")
        }
        return results
    }

    // MARK: - Helpers

    static func normalizeCategoryId(_ categoryStr: String, type: TransactionType, validCategoryIds: Set<String> = []) -> String {
        // With the user's categories known, only those (and the fallbacks) are valid
        if !validCategoryIds.isEmpty {
            if validCategoryIds.contains(categoryStr) || fallbackCategoryIds.contains(categoryStr) {
                return categoryStr
            }
            return type == .income ? "other_income" : "other_expense"
        }

        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        let expenseCategories: Set<String> = ["food_drink", "groceries", "transport", "housing", "bills_utilities", "shopping", "health", "education", "entertainment", "personal_care", "gifts", "family", "insurance", "savings_invest", "debt_payment", "pets", "travel", "other_expense"]

        if type == .income {
            return incomeCategories.contains(categoryStr) ? categoryStr : "other_income"
        } else {
            return expenseCategories.contains(categoryStr) ? categoryStr : "other_expense"
        }
    }

    /// The category's own type when it is one of the user's categories, so a
    /// custom income category stays income.
    static func typeFromCategory(_ categoryId: String, categories: [Category]) -> TransactionType {
        categories.first { $0.id == categoryId }?.type ?? typeFromCategory(categoryId)
    }

    /// Type for the built-in category IDs; anything unknown is an expense.
    static func typeFromCategory(_ categoryId: String) -> TransactionType {
        let incomeCategories: Set<String> = ["salary", "freelance", "bonus", "investment_income", "interest", "gift_received", "refund", "other_income"]
        return incomeCategories.contains(categoryId) ? .income : .expense
    }

    static func parseDate(_ dateStr: String, calendar: Calendar = .current) -> Date {
        let now = Date.now
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
        // The model always returns Gregorian YYYY-MM-DD, so read it with a fixed
        // POSIX + Gregorian formatter. Without this, a device set to the Japanese
        // or Buddhist calendar reads "2026" as an era year and every date falls back to today.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
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
    static func _makeModel(
        ai: FirebaseAI,
        categories: [Category],
        wallets: [Wallet],
        defaultWalletId: String,
        language: String,
        currency: String
    ) -> GenerativeModel {
        ai.generativeModel(
            modelName: AppConstants.geminiModelName,
            // Gemini 3.x: keep default temperature (lower values can cause looping)
            // and use low thinking, since parsing doesn't need deep reasoning.
            // Thinking tokens count toward maxOutputTokens, so leave headroom
            // for long date ranges (one transaction per day).
            generationConfig: GenerationConfig(
                maxOutputTokens: 4096,
                responseMIMEType: "application/json",
                responseSchema: _responseSchema(
                    categoryIds: allowedCategoryIds(for: categories),
                    walletIds: activeWallets(wallets).map(\.id)
                ),
                thinkingConfig: ThinkingConfig(thinkingLevel: .low)
            ),
            systemInstruction: ModelContent(role: "system", parts: buildInstructions(
                categories: categories,
                wallets: wallets,
                defaultWalletId: defaultWalletId,
                language: language,
                currency: currency
            ))
        )
    }

    /// The response shape that `parseResponse` reads. The category must be one
    /// of the user's category IDs, so the model cannot invent one. With 2+
    /// wallets the model may also name a wallet and return transfers.
    static func _responseSchema(categoryIds: [String], walletIds: [String]) -> Schema {
        let canTransfer = walletIds.count > 1
        var properties: [String: Schema] = [
            "amount": .double(description: "Positive amount in the user's currency"),
            "description": .string(description: "A few words, in the language the user spoke"),
            "category": .enumeration(values: categoryIds),
            "type": .enumeration(values: canTransfer ? ["expense", "income", "transfer"] : ["expense", "income"]),
            "date": .string(description: "YYYY-MM-DD"),
            "confidence": .double(description: "0 to 1"),
        ]
        var optional: [String] = []
        if canTransfer {
            properties["wallet"] = .enumeration(values: walletIds)
            properties["to_wallet"] = .enumeration(values: walletIds)
            optional = ["wallet", "to_wallet"]
        }
        return .object(properties: [
            "transactions": .array(items: .object(properties: properties, optionalProperties: optional)),
        ])
    }

    static func _parseWithFirebase(
        input: String,
        categories: [Category],
        language: String,
        wallets: [Wallet],
        defaultWalletId: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        guard let ai = _firebaseAI else { return [] }

        let model = _makeModel(
            ai: ai,
            categories: categories,
            wallets: wallets,
            defaultWalletId: defaultWalletId,
            language: language,
            currency: currency
        )

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
                AnalyticsService.logGeminiParseFailed(errorReason: "empty_response", language: language)
                return []
            }

            #if DEBUG
            print("[GeminiParser] Raw Gemini response: \(text)")
            #endif

            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[GeminiParser] Failed to parse JSON from response")
                AnalyticsService.logGeminiParseFailed(errorReason: "bad_json", language: language)
                return []
            }

            let results = parseResponse(
                jsonData: json,
                language: language,
                categories: categories,
                wallets: wallets,
                defaultWalletId: defaultWalletId
            )
            if !results.isEmpty {
                usageLimitService.incrementUsage()
                print("[GeminiParser] Successfully parsed \(results.count) transaction(s), usage incremented")
            } else {
                print("[GeminiParser] No valid transactions extracted from response")
                AnalyticsService.logGeminiParseFailed(errorReason: "no_transactions", language: language)
            }
            return results
        } catch is GeminiTimeoutError {
            print("[GeminiParser] Gemini API timed out after \(AppConstants.geminiApiTimeoutSeconds)s")
            AnalyticsService.logGeminiParseFailed(errorReason: "timeout", language: language)
            return []
        } catch {
            print("[GeminiParser] Error calling Gemini: \(error)")
            AnalyticsService.logGeminiParseFailed(
                errorReason: "api_error",
                language: language,
                errorCode: AnalyticsService.errorCode(error)
            )
            return []
        }
    }
}

private struct GeminiTimeoutError: Error {}

#endif

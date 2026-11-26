import Foundation

/// Asks Gemini (Firebase AI Logic) which category a bank-alert note belongs
/// to. Sends only the note, which is the transfer counterparty or the
/// transaction description, plus whether it is income or expense: never the
/// amount, account number or balance. Used for Premium users only.
struct GeminiCategorizer: TransactionCategorizing {
    @MainActor
    func categoryId(note: String, type: TransactionType, allowedCategoryIds: [String], language: String) async -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !allowedCategoryIds.isEmpty else { return nil }
        #if canImport(FirebaseAILogic)
        return await GeminiParserService._categorize(note: trimmed, type: type, allowedCategoryIds: allowedCategoryIds)
        #else
        return nil
        #endif
    }

    /// Instructions sent with each request (kept testable without the SDK).
    static func instructions(type: TransactionType) -> String {
        """
        You categorize one Vietnamese bank transaction for a personal expense tracker.
        The user gives only the transaction note: a merchant, a transfer recipient or sender name, or the bank's description, usually without Vietnamese diacritics.
        The transaction is \(type == .income ? "money received (income)" : "money spent (expense)").
        Answer with the single best category id from the allowed list.
        If the note is only a person's name or gives no clue, answer \(type == .income ? "other_income" : "other_expense").
        """
    }
}

#if canImport(FirebaseAILogic)
import FirebaseAILogic

extension GeminiParserService {
    @MainActor
    static func _categorize(note: String, type: TransactionType, allowedCategoryIds: [String]) async -> String? {
        if !isAvailable { initialize() }
        guard isAvailable else { return nil }
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: AppConstants.geminiModelName,
            generationConfig: GenerationConfig(
                maxOutputTokens: 512,
                responseMIMEType: "application/json",
                responseSchema: .object(properties: ["category": .enumeration(values: allowedCategoryIds)]),
                thinkingConfig: ThinkingConfig(thinkingLevel: .low)
            ),
            systemInstruction: ModelContent(role: "system", parts: GeminiCategorizer.instructions(type: type))
        )
        do {
            let response = try await withThrowingTaskGroup(of: GenerateContentResponse.self) { group in
                group.addTask { try await model.generateContent(note) }
                group.addTask {
                    try await Task.sleep(for: .seconds(AppConstants.geminiApiTimeoutSeconds))
                    throw GeminiTimeoutError()
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            guard let data = response.text?.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let category = json["category"] as? String,
                  allowedCategoryIds.contains(category) else { return nil }
            return category
        } catch {
            print("[GeminiCategorizer] Categorize failed: \(error)")
            return nil
        }
    }
}
#endif

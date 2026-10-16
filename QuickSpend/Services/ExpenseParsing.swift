import Foundation

/// Abstraction over the Gemini parser so callers (App Intent, voice flow, tests)
/// can swap in deterministic mocks without touching the Firebase SDK.
@MainActor
protocol ExpenseParsing {
    func parse(
        input: String,
        categories: [Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction]
}

/// Production adapter that forwards to `GeminiParserService`.
struct GeminiExpenseParser: ExpenseParsing {
    func parse(
        input: String,
        categories: [Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        await GeminiParserService.parse(
            input: input,
            categories: categories,
            language: language,
            currency: currency,
            usageLimitService: usageLimitService
        )
    }
}

/// When a voice parse is trusted enough to save without a confirmation step.
/// Shared by the Siri intent and the in-app voice flow so both behave the same.
enum VoiceAutoSavePolicy {
    static let confidenceThreshold: Double = 0.9

    /// True when every parsed transaction meets the threshold. One ambiguous
    /// item sends the whole batch to confirmation so the user can still cancel.
    static func shouldAutoSave(_ parsed: [ParsedTransaction]) -> Bool {
        guard !parsed.isEmpty else { return false }
        return parsed.allSatisfy { $0.confidence >= confidenceThreshold }
    }
}

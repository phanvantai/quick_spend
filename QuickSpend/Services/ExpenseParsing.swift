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

import Foundation
import Testing
@testable import QuickSpend

/// Records events instead of sending them to Firebase.
final class MockAnalyticsLogger: AnalyticsLogging {
    private(set) var events: [(name: String, parameters: [String: Any])] = []

    func logEvent(_ name: String, parameters: [String: Any]) {
        events.append((name, parameters))
    }

    func events(named name: String) -> [[String: Any]] {
        events.filter { $0.name == name }.map(\.parameters)
    }
}

@Suite("VoiceAnalytics Tests")
struct VoiceAnalyticsTests {

    private let date = Date(timeIntervalSince1970: 1_900_000_000)

    private func item(
        confidence: Double,
        categoryId: String = "food_drink",
        type: TransactionType = .expense,
        walletId: String? = nil
    ) -> ParsedTransaction {
        var parsed = ParsedTransaction(
            amount: 12_345, note: "secret note test", categoryId: categoryId,
            type: type, date: date, confidence: confidence, rawInput: "secret words test"
        )
        parsed.walletId = walletId
        return parsed
    }

    private func transferItem(to: String = "wallet_bank_test") -> ParsedTransaction {
        var parsed = item(confidence: 0.95, categoryId: Transfer.categoryId, walletId: "wallet_cash_test")
        parsed.transferToWalletId = to
        return parsed
    }

    // MARK: - Result parameters

    @Test("A result reports outcome, counts, and the lowest confidence")
    func testResultParameters() {
        let parameters = VoiceAnalytics.resultParameters(
            source: .widget,
            outcome: .review,
            items: [item(confidence: 0.95), item(confidence: 0.734, type: .income)],
            language: "vi",
            recordSeconds: 4,
            parseMs: 1_250
        )
        #expect(parameters["source"] as? String == "widget")
        #expect(parameters["outcome"] as? String == "review")
        #expect(parameters["language"] as? String == "vi")
        #expect(parameters["item_count"] as? Int == 2)
        #expect(parameters["min_confidence"] as? Double == 0.73)
        #expect(parameters["confidence_band"] as? String == "medium")
        #expect(parameters["has_income"] as? Int == 1)
        #expect(parameters["has_transfer"] as? Int == 0)
        #expect(parameters["has_other_category"] as? Int == 0)
        #expect(parameters["record_seconds"] as? Int == 4)
        #expect(parameters["parse_ms"] as? Int == 1_250)
    }

    @Test("A result never contains what the user said, notes, or amounts")
    func testResultIsPrivacySafe() {
        let parameters = VoiceAnalytics.resultParameters(
            source: .hold, outcome: .autoSaved, items: [item(confidence: 0.95)],
            language: "en", recordSeconds: nil, parseMs: nil
        )
        let values = parameters.values.map { "\($0)" }
        #expect(!values.contains { $0.contains("secret") })
        #expect(!values.contains { $0.contains("12345") })
        #expect(parameters["record_seconds"] == nil)
        #expect(parameters["parse_ms"] == nil)
    }

    @Test("Transfers and fallback categories are flagged; a transfer is not income")
    func testTransferAndFallbackFlags() {
        let parameters = VoiceAnalytics.resultParameters(
            source: .siri, outcome: .review,
            items: [transferItem(), item(confidence: 0.6, categoryId: "other_expense")],
            language: "en", recordSeconds: nil, parseMs: nil
        )
        #expect(parameters["has_transfer"] as? Int == 1)
        #expect(parameters["has_income"] as? Int == 0)
        #expect(parameters["has_other_category"] as? Int == 1)
        #expect(parameters["confidence_band"] as? String == "low")
    }

    @Test("A result without items has no confidence fields")
    func testEmptyResult() {
        let parameters = VoiceAnalytics.resultParameters(
            source: .hold, outcome: .noSpeech, items: [], language: "en", recordSeconds: 2, parseMs: nil
        )
        #expect(parameters["item_count"] as? Int == 0)
        #expect(parameters["min_confidence"] == nil)
        #expect(parameters["confidence_band"] == nil)
    }

    @Test("Confidence bands follow the auto-save and review thresholds")
    func testConfidenceBands() {
        #expect(VoiceAnalytics.confidenceBand(0.95) == "high")
        #expect(VoiceAnalytics.confidenceBand(VoiceAutoSavePolicy.confidenceThreshold) == "high")
        #expect(VoiceAnalytics.confidenceBand(0.89) == "medium")
        #expect(VoiceAnalytics.confidenceBand(GeminiParserService.uncertainConfidence) == "low")
        #expect(VoiceAnalytics.confidenceBand(0.3) == "low")
    }

    // MARK: - Edited detection

    @Test("Saving exactly what was parsed is not an edit")
    func testUnchangedIsNotEdited() throws {
        let parsed = [item(confidence: 0.8), transferItem()]
        let saved = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: "wallet_default_test")
        #expect(!VoiceAnalytics.wasEdited(parsed: parsed, saved: saved, defaultWalletId: "wallet_default_test"))
    }

    @Test("Changing amount, category, or wallet counts as an edit")
    func testChangesAreEdits() throws {
        let parsed = [item(confidence: 0.8)]
        let original = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: "wallet_default_test")

        let amount = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: "wallet_default_test")
        amount[0].amount = 99
        let category = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: "wallet_default_test")
        category[0].categoryId = "shopping"
        let wallet = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: "wallet_other_test")

        #expect(!VoiceAnalytics.wasEdited(parsed: parsed, saved: original, defaultWalletId: "wallet_default_test"))
        #expect(VoiceAnalytics.wasEdited(parsed: parsed, saved: amount, defaultWalletId: "wallet_default_test"))
        #expect(VoiceAnalytics.wasEdited(parsed: parsed, saved: category, defaultWalletId: "wallet_default_test"))
        #expect(VoiceAnalytics.wasEdited(parsed: parsed, saved: wallet, defaultWalletId: "wallet_default_test"))
        #expect(VoiceAnalytics.wasEdited(parsed: parsed, saved: [], defaultWalletId: "wallet_default_test"))
    }

    @Test("Completing an unclear transfer always counts as an edit")
    func testIncompleteTransferIsEdited() throws {
        let parsed = [transferItem(to: "")]
        let saved = try VoiceTransactionBuilder.transactions(from: [transferItem()], defaultWalletId: "wallet_default_test")
        #expect(VoiceAnalytics.wasEdited(parsed: parsed, saved: saved, defaultWalletId: "wallet_default_test"))
    }

    // MARK: - Events

    @Test("Start, cancel, and review events carry their parameters")
    func testEventParameters() {
        let logger = MockAnalyticsLogger()
        let analytics = VoiceAnalytics(logger: logger)

        analytics.logStarted(source: .widget, language: "ja")
        analytics.logCancelled(source: .hold, language: "en", recordSeconds: 3)
        analytics.logReviewClosed(source: .siri, saved: false, edited: false, itemCount: 2)

        #expect(logger.events.map(\.name) == ["voice_started", "voice_cancelled", "voice_review_closed"])
        #expect(logger.events[0].parameters["source"] as? String == "widget")
        #expect(logger.events[0].parameters["language"] as? String == "ja")
        #expect(logger.events[1].parameters["record_seconds"] as? Int == 3)
        #expect(logger.events[2].parameters["action"] as? String == "discarded")
        #expect(logger.events[2].parameters["edited"] as? Int == 0)
        #expect(logger.events[2].parameters["item_count"] as? Int == 2)
    }

    @Test("Siri parse errors map to voice outcomes")
    func testOutcomeFromSiriError() {
        struct OtherError: Error {}
        #expect(VoiceAnalytics.Outcome(error: AddExpenseError.limitReached(language: "en")) == .limitReached)
        #expect(VoiceAnalytics.Outcome(error: AddExpenseError.couldNotParse(language: "en")) == .failed)
        #expect(VoiceAnalytics.Outcome(error: AddExpenseError.incompleteTransfer(language: "en")) == .incompleteTransfer)
        #expect(VoiceAnalytics.Outcome(error: AddExpenseError.noCategories(language: "en")) == nil)
        #expect(VoiceAnalytics.Outcome(error: OtherError()) == nil)
    }

    @Test("API error codes are short and carry no message text")
    func testErrorCode() {
        let error = NSError(domain: "TestDomain", code: 403, userInfo: [NSLocalizedDescriptionKey: "secret detail test"])
        #expect(AnalyticsService.errorCode(error) == "TestDomain:403")
    }
}

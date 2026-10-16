import Foundation

/// Where analytics events go. Production forwards to `AnalyticsService`
/// (Firebase); tests inject a recorder.
protocol AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any])
}

struct FirebaseAnalyticsLogger: AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]) {
        AnalyticsService.logEvent(name, parameters: parameters)
    }
}

/// Voice funnel events: started → cancelled, or a result (auto-saved, review,
/// failed …) → review saved / discarded.
///
/// Privacy: never logs what the user said, notes, or amounts — only counts,
/// confidence, and which path the capture took.
struct VoiceAnalytics {

    enum Source: String {
        /// Hold-to-record on the in-app mic button.
        case hold
        /// Hands-free recording from the widget or Control Center.
        case widget
        case siri
    }

    enum Outcome: String {
        /// Every item was confident and saved without review.
        case autoSaved = "auto_saved"
        /// Shown for review (in-app sheet or Siri confirmation card).
        case review
        /// The parser returned nothing usable.
        case failed
        /// Recording ended with no words heard.
        case noSpeech = "no_speech"
        case limitReached = "limit_reached"
        /// AI parsing is not available in this build.
        case unavailable
        /// Siri heard a transfer but not both wallets.
        case incompleteTransfer = "incomplete_transfer"
    }

    static let started = "voice_started"
    static let cancelled = "voice_cancelled"
    static let result = "voice_result"
    static let reviewClosed = "voice_review_closed"

    let logger: AnalyticsLogging

    init(logger: AnalyticsLogging = FirebaseAnalyticsLogger()) {
        self.logger = logger
    }

    func logStarted(source: Source, language: String) {
        logger.logEvent(Self.started, parameters: [
            "source": source.rawValue,
            "language": language,
        ])
    }

    func logCancelled(source: Source, language: String, recordSeconds: Int) {
        logger.logEvent(Self.cancelled, parameters: [
            "source": source.rawValue,
            "language": language,
            "record_seconds": recordSeconds,
        ])
    }

    func logResult(
        source: Source,
        outcome: Outcome,
        items: [ParsedTransaction] = [],
        language: String,
        recordSeconds: Int? = nil,
        parseMs: Int? = nil
    ) {
        logger.logEvent(Self.result, parameters: Self.resultParameters(
            source: source,
            outcome: outcome,
            items: items,
            language: language,
            recordSeconds: recordSeconds,
            parseMs: parseMs
        ))
    }

    func logReviewClosed(source: Source, saved: Bool, edited: Bool, itemCount: Int) {
        logger.logEvent(Self.reviewClosed, parameters: [
            "source": source.rawValue,
            "action": saved ? "saved" : "discarded",
            "edited": edited ? 1 : 0,
            "item_count": itemCount,
        ])
    }

    // MARK: - Parameters

    static func resultParameters(
        source: Source,
        outcome: Outcome,
        items: [ParsedTransaction],
        language: String,
        recordSeconds: Int?,
        parseMs: Int?
    ) -> [String: Any] {
        var parameters: [String: Any] = [
            "source": source.rawValue,
            "outcome": outcome.rawValue,
            "language": language,
            "item_count": items.count,
        ]
        if let minConfidence = items.map(\.confidence).min() {
            // Rounded so the value is a readable bucket, not a raw float.
            parameters["min_confidence"] = (minConfidence * 100).rounded() / 100
            parameters["confidence_band"] = confidenceBand(minConfidence)
            parameters["has_transfer"] = items.contains(where: \.isTransfer) ? 1 : 0
            parameters["has_income"] = items.contains { !$0.isTransfer && $0.type == .income } ? 1 : 0
            parameters["has_other_category"] = items.contains { $0.categoryId.hasPrefix("other") } ? 1 : 0
        }
        if let recordSeconds { parameters["record_seconds"] = recordSeconds }
        if let parseMs { parameters["parse_ms"] = parseMs }
        return parameters
    }

    /// "high" auto-saves, "medium" is a normal review, "low" is one the app
    /// itself flagged (fallback category, future date, unclear transfer).
    static func confidenceBand(_ confidence: Double) -> String {
        if confidence >= VoiceAutoSavePolicy.confidenceThreshold { return "high" }
        if confidence > GeminiParserService.uncertainConfidence { return "medium" }
        return "low"
    }

    /// True when what the user saved differs from what was parsed (amount,
    /// category, type, wallet, day, or number of rows). A parse that could
    /// not be built as-is (an unclear transfer) always counts as edited.
    static func wasEdited(
        parsed: [ParsedTransaction],
        saved: [Transaction],
        defaultWalletId: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard let original = try? VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: defaultWalletId) else {
            return true
        }
        func key(_ transaction: Transaction) -> String {
            let day = calendar.startOfDay(for: transaction.date).timeIntervalSince1970
            return "\(transaction.amount)|\(transaction.categoryId)|\(transaction.type.rawValue)|\(transaction.walletId)|\(day)"
        }
        return original.map(key).sorted() != saved.map(key).sorted()
    }
}

extension VoiceAnalytics.Outcome {
    /// The outcome for a Siri parse that stopped with an error; nil for
    /// errors that are not about the parse (no categories, save failure).
    init?(error: Error) {
        guard let error = error as? AddExpenseError else { return nil }
        switch error {
        case .limitReached: self = .limitReached
        case .couldNotParse: self = .failed
        case .incompleteTransfer: self = .incompleteTransfer
        case .noCategories, .saveFailed: return nil
        }
    }
}

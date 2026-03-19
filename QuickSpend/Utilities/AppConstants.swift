import Foundation

/// Application-wide constants and configuration values
enum AppConstants {

    // MARK: - User Configuration

    static let defaultUserId = "local_user"

    // MARK: - Subscription & Monetization

    static let subscriptionMonthlyPriceUSD = 2.99
    static let subscriptionYearlyPriceUSD = 24.99
    static let termsOfUseUrl = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let privacyPolicyUrl = "https://quickspend.taiphanvan.dev/privacy.html"
    static let freeTierGeminiLimit = 3
    static let freeTierRecurringTemplatesLimit = 3
    static let freeTierReportDaysLimit = 7

    // MARK: - API & Network

    static let geminiApiTimeoutSeconds = 30
    static let geminiDailyParsingLimit = 3
    static let geminiWarningThreshold = 5
    static let geminiCriticalThreshold = 3

    // MARK: - Voice Input

    static let minVoiceInputLength = 2
    static let maxVoiceInputLength = 500
    static let voiceStopDelayMs = 100
    static let holdToRecordMinDuration: TimeInterval = 0.2
    static let dragCancelThreshold: CGFloat = 80

    // MARK: - Expense & Transaction Limits

    static let maxExpenseAmount: Double = 999_999_999_999
    static let minExpenseAmount: Double = 0.01
    static let maxDescriptionLength = 500
    static let maxCategoryNameLength = 50

    // MARK: - Recurring Expenses

    static let maxRecurringInstancesPerGeneration = 100
    static let maxRecurringYearsAhead = 5

    // MARK: - Date Validation

    static let maxYearsInPast = 10
    static let maxYearsInFuture = 1

    // MARK: - UI & UX

    static let expensesPerPage = 50
    static let topExpensesCount = 5
    static let standardAnimationDurationMs = 300

    // MARK: - Confidence Thresholds

    static let minParsingConfidence: Double = 0.5
    static let confidenceWarningThreshold: Double = 0.7
    static let highConfidenceThreshold: Double = 0.9

    // MARK: - Feature Requests

    static let featureRequestsCollection = "feature_requests"
    static let maxFeatureRequestTitleLength = 100
    static let maxFeatureRequestDescriptionLength = 1000

    // MARK: - Debug / Admin

    static let debugModeActivationTaps = 5
    static let debugModeActivationWindowSeconds: TimeInterval = 3
    static let adminModeActivationTaps = 7
}

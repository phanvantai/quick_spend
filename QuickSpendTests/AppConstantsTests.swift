import Testing
import Foundation
@testable import QuickSpend

@Suite("AppConstants Tests")
struct AppConstantsTests {

    // MARK: - Subscription Constants

    @Test("Free tier limits are positive")
    func testFreeTierLimits() {
        #expect(AppConstants.freeTierGeminiLimit > 0)
        #expect(AppConstants.freeTierRecurringTemplatesLimit > 0)
        #expect(AppConstants.freeTierReportDaysLimit > 0)
    }

    @Test("Free tier Gemini limit is 5")
    func testFreeTierGeminiLimit() {
        #expect(AppConstants.freeTierGeminiLimit == 5)
    }

    @Test("Free tier recurring templates limit is 3")
    func testFreeTierRecurringLimit() {
        #expect(AppConstants.freeTierRecurringTemplatesLimit == 3)
    }

    @Test("Free tier report days limit is 7")
    func testFreeTierReportDays() {
        #expect(AppConstants.freeTierReportDaysLimit == 7)
    }

    // MARK: - Voice Input

    @Test("Voice input min length is reasonable")
    func testVoiceInputMinLength() {
        #expect(AppConstants.minVoiceInputLength >= 1)
        #expect(AppConstants.minVoiceInputLength <= 10)
    }

    @Test("Voice input max length is reasonable")
    func testVoiceInputMaxLength() {
        #expect(AppConstants.maxVoiceInputLength > AppConstants.minVoiceInputLength)
        #expect(AppConstants.maxVoiceInputLength == 500)
    }

    // MARK: - Expense Limits

    @Test("Expense amount limits are valid")
    func testExpenseAmountLimits() {
        #expect(AppConstants.maxExpenseAmount > AppConstants.minExpenseAmount)
        #expect(AppConstants.minExpenseAmount > 0)
    }

    @Test("Description length limit is positive")
    func testDescriptionLength() {
        #expect(AppConstants.maxDescriptionLength > 0)
        #expect(AppConstants.maxDescriptionLength == 500)
    }

    // MARK: - Recurring

    @Test("Max recurring instances per generation is 100")
    func testMaxRecurringInstances() {
        #expect(AppConstants.maxRecurringInstancesPerGeneration == 100)
    }

    @Test("Max recurring years ahead is positive")
    func testMaxRecurringYearsAhead() {
        #expect(AppConstants.maxRecurringYearsAhead > 0)
    }

    // MARK: - Confidence Thresholds

    @Test("Confidence thresholds are ordered correctly")
    func testConfidenceThresholds() {
        #expect(AppConstants.minParsingConfidence < AppConstants.confidenceWarningThreshold)
        #expect(AppConstants.confidenceWarningThreshold < AppConstants.highConfidenceThreshold)
    }

    @Test("Confidence thresholds are between 0 and 1")
    func testConfidenceRange() {
        #expect(AppConstants.minParsingConfidence >= 0)
        #expect(AppConstants.minParsingConfidence <= 1)
        #expect(AppConstants.highConfidenceThreshold >= 0)
        #expect(AppConstants.highConfidenceThreshold <= 1)
    }

    // MARK: - Debug

    @Test("Debug mode activation requires multiple taps")
    func testDebugModeActivation() {
        #expect(AppConstants.debugModeActivationTaps > 1)
        #expect(AppConstants.adminModeActivationTaps > AppConstants.debugModeActivationTaps)
    }

    // MARK: - Feature Requests

    @Test("Feature request limits are positive")
    func testFeatureRequestLimits() {
        #expect(AppConstants.maxFeatureRequestTitleLength > 0)
        #expect(AppConstants.maxFeatureRequestDescriptionLength > AppConstants.maxFeatureRequestTitleLength)
    }

    // MARK: - Date Validation

    @Test("Date validation ranges are positive")
    func testDateValidation() {
        #expect(AppConstants.maxYearsInPast > 0)
        #expect(AppConstants.maxYearsInFuture > 0)
    }

    // MARK: - UI

    @Test("UI constants are positive")
    func testUIConstants() {
        #expect(AppConstants.expensesPerPage > 0)
        #expect(AppConstants.topExpensesCount > 0)
        #expect(AppConstants.standardAnimationDurationMs > 0)
    }
}

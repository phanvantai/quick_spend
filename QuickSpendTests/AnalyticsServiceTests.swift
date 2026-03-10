import Testing
import Foundation
@testable import QuickSpend

@Suite("AnalyticsService Tests")
struct AnalyticsServiceTests {

    // MARK: - getAmountRange

    @Test("Amount range under 10k")
    func testAmountRangeUnder10k() {
        #expect(AnalyticsService.getAmountRange(0) == "0-10k")
        #expect(AnalyticsService.getAmountRange(5000) == "0-10k")
        #expect(AnalyticsService.getAmountRange(9999) == "0-10k")
    }

    @Test("Amount range 10k-100k")
    func testAmountRange10k100k() {
        #expect(AnalyticsService.getAmountRange(10_000) == "10k-100k")
        #expect(AnalyticsService.getAmountRange(50_000) == "10k-100k")
        #expect(AnalyticsService.getAmountRange(99_999) == "10k-100k")
    }

    @Test("Amount range 100k-1m")
    func testAmountRange100k1m() {
        #expect(AnalyticsService.getAmountRange(100_000) == "100k-1m")
        #expect(AnalyticsService.getAmountRange(500_000) == "100k-1m")
        #expect(AnalyticsService.getAmountRange(999_999) == "100k-1m")
    }

    @Test("Amount range 1m+")
    func testAmountRange1mPlus() {
        #expect(AnalyticsService.getAmountRange(1_000_000) == "1m+")
        #expect(AnalyticsService.getAmountRange(10_000_000) == "1m+")
        #expect(AnalyticsService.getAmountRange(999_999_999) == "1m+")
    }

    @Test("Amount range boundary values")
    func testAmountRangeBoundaries() {
        #expect(AnalyticsService.getAmountRange(9_999.99) == "0-10k")
        #expect(AnalyticsService.getAmountRange(10_000) == "10k-100k")
        #expect(AnalyticsService.getAmountRange(99_999.99) == "10k-100k")
        #expect(AnalyticsService.getAmountRange(100_000) == "100k-1m")
    }

    // MARK: - getExpenseAgeDays

    @Test("Expense age for today is 0")
    func testExpenseAgeToday() {
        let days = AnalyticsService.getExpenseAgeDays(.now)
        #expect(days == 0)
    }

    @Test("Expense age for past dates")
    func testExpenseAgePast() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: .now)!
        let days = AnalyticsService.getExpenseAgeDays(threeDaysAgo)
        #expect(days == 3)
    }

    @Test("Expense age for 30 days ago")
    func testExpenseAge30Days() {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now)!
        let days = AnalyticsService.getExpenseAgeDays(thirtyDaysAgo)
        #expect(days == 30)
    }

    // MARK: - Event Logging (Smoke Tests)
    // These verify the methods don't crash; actual Firebase logging is gated behind #if canImport

    @Test("logEvent does not crash")
    func testLogEvent() {
        AnalyticsService.logEvent("test_event", parameters: ["key": "value"])
    }

    @Test("logScreenView does not crash")
    func testLogScreenView() {
        AnalyticsService.logScreenView("test_screen")
    }

    @Test("Screen view convenience methods do not crash")
    func testScreenViewConvenienceMethods() {
        AnalyticsService.logOnboardingScreen()
        AnalyticsService.logHomeScreen()
        AnalyticsService.logTransactionsScreen()
        AnalyticsService.logSettingsScreen()
        AnalyticsService.logCategoriesScreen()
        AnalyticsService.logRecurringScreen()
    }

    @Test("logExpenseFormScreen does not crash")
    func testLogExpenseFormScreen() {
        AnalyticsService.logExpenseFormScreen(isEdit: false)
        AnalyticsService.logExpenseFormScreen(isEdit: true)
    }

    @Test("logCategoryFormScreen does not crash")
    func testLogCategoryFormScreen() {
        AnalyticsService.logCategoryFormScreen(isEdit: false)
        AnalyticsService.logCategoryFormScreen(isEdit: true)
    }

    @Test("logRecurringFormScreen does not crash")
    func testLogRecurringFormScreen() {
        AnalyticsService.logRecurringFormScreen(isEdit: false)
        AnalyticsService.logRecurringFormScreen(isEdit: true)
    }

    @Test("Expense event logging does not crash")
    func testExpenseEventLogging() {
        AnalyticsService.logExpenseAdded(method: "manual", category: "food_drink", amountRange: "0-10k", language: "en", transactionType: "expense")
        AnalyticsService.logExpenseEdited(fieldsChanged: ["amount", "note"], category: "food_drink")
        AnalyticsService.logExpenseDeleted(category: "food_drink", ageDays: 5)
    }

    @Test("Voice event logging does not crash")
    func testVoiceEventLogging() {
        AnalyticsService.logVoiceInputStarted(language: "en")
        AnalyticsService.logVoiceInputCompleted(success: true, durationSeconds: 5, language: "en")
        AnalyticsService.logVoiceInputCancelled(language: "en")
    }

    @Test("Category event logging does not crash")
    func testCategoryEventLogging() {
        AnalyticsService.logCategoryCreated(isCustom: true)
        AnalyticsService.logCategoryEdited(categoryName: "Food")
        AnalyticsService.logCategoryDeleted(categoryName: "Food")
    }

    @Test("Recurring event logging does not crash")
    func testRecurringEventLogging() {
        AnalyticsService.logRecurringTemplateCreated(pattern: "monthly", category: "housing")
        AnalyticsService.logRecurringTemplateToggled(isActive: true, category: "housing")
        AnalyticsService.logRecurringTemplateDeleted(category: "housing")
    }

    @Test("AI parser event logging does not crash")
    func testAIParserEventLogging() {
        AnalyticsService.logGeminiParseSuccess(confidence: 0.95, expenseCount: 2, language: "en")
        AnalyticsService.logGeminiParseFailed(errorReason: "empty_response", language: "en")
        AnalyticsService.logGeminiLimitReached(remainingCount: 0)
    }

    @Test("Settings event logging does not crash")
    func testSettingsEventLogging() {
        AnalyticsService.logLanguageChanged(from: "en", to: "vi")
        AnalyticsService.logCurrencyChanged(from: "USD", to: "VND")
        AnalyticsService.logThemeChanged(from: "system", to: "dark")
        AnalyticsService.logOnboardingCompleted(language: "en", currency: "USD")
    }

    @Test("User property setting does not crash")
    func testUserPropertySetting() {
        AnalyticsService.setLanguageProperty("en")
        AnalyticsService.setCurrencyProperty("USD")
        AnalyticsService.setThemeModeProperty("system")
    }

    @Test("setUserProperty does not crash")
    func testSetUserProperty() {
        AnalyticsService.setUserProperty(name: "test_prop", value: "test_value")
    }
}

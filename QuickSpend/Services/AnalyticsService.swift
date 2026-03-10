import Foundation

/// Analytics service for tracking user behavior and app performance
/// Privacy-aware: Never logs PII (amounts, descriptions, personal data)
///
/// NOTE: Requires FirebaseAnalytics SDK added via SPM. Until then,
/// events are logged to console only.
enum AnalyticsService {

    private static var isEnabled = false

    // MARK: - Initialization

    /// Initialize analytics
    /// Call from QuickSpendApp after Firebase.configure()
    static func initialize() {
        #if canImport(FirebaseAnalytics)
        _initializeFirebase()
        #else
        print("[Analytics] Firebase Analytics not available. Add firebase-ios-sdk via SPM to enable.")
        #endif
    }

    // MARK: - Core Logging

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        _logFirebaseEvent(name, parameters: parameters)
        #endif
        #if DEBUG
        print("[Analytics] Event: \(name) \(parameters ?? [:])")
        #endif
    }

    static func logScreenView(_ screenName: String) {
        #if canImport(FirebaseAnalytics)
        _logFirebaseScreenView(screenName)
        #endif
        #if DEBUG
        print("[Analytics] Screen: \(screenName)")
        #endif
    }

    static func setUserProperty(name: String, value: String) {
        #if canImport(FirebaseAnalytics)
        _setFirebaseUserProperty(name: name, value: value)
        #endif
        #if DEBUG
        print("[Analytics] User property: \(name) = \(value)")
        #endif
    }

    // MARK: - Screen Views

    static func logOnboardingScreen() { logScreenView("onboarding") }
    static func logHomeScreen() { logScreenView("home") }
    static func logTransactionsScreen() { logScreenView("transactions") }
    static func logSettingsScreen() { logScreenView("settings") }
    static func logCategoriesScreen() { logScreenView("categories") }
    static func logRecurringScreen() { logScreenView("recurring_expenses") }

    static func logExpenseFormScreen(isEdit: Bool) {
        logScreenView(isEdit ? "expense_edit" : "expense_add")
    }
    static func logCategoryFormScreen(isEdit: Bool) {
        logScreenView(isEdit ? "category_edit" : "category_add")
    }
    static func logRecurringFormScreen(isEdit: Bool) {
        logScreenView(isEdit ? "recurring_edit" : "recurring_add")
    }

    // MARK: - Expense Events

    static func logExpenseAdded(method: String, category: String, amountRange: String, language: String, transactionType: String) {
        logEvent("expense_added", parameters: [
            "method": method,
            "category": category,
            "amount_range": amountRange,
            "language": language,
            "transaction_type": transactionType,
        ])
    }

    static func logExpenseEdited(fieldsChanged: [String], category: String) {
        logEvent("expense_edited", parameters: [
            "fields_changed": fieldsChanged.joined(separator: ","),
            "category": category,
        ])
    }

    static func logExpenseDeleted(category: String, ageDays: Int) {
        logEvent("expense_deleted", parameters: [
            "category": category,
            "age_days": ageDays,
        ])
    }

    // MARK: - Voice Events

    static func logVoiceInputStarted(language: String) {
        logEvent("voice_input_started", parameters: ["language": language])
    }

    static func logVoiceInputCompleted(success: Bool, durationSeconds: Int, language: String) {
        logEvent("voice_input_completed", parameters: [
            "success": success ? 1 : 0,
            "duration_seconds": durationSeconds,
            "language": language,
        ])
    }

    static func logVoiceInputCancelled(language: String) {
        logEvent("voice_input_cancelled", parameters: ["language": language])
    }

    // MARK: - Category Events

    static func logCategoryCreated(isCustom: Bool) {
        logEvent("category_created", parameters: ["is_custom": isCustom])
    }

    static func logCategoryEdited(categoryName: String) {
        logEvent("category_edited", parameters: ["category": categoryName])
    }

    static func logCategoryDeleted(categoryName: String) {
        logEvent("category_deleted", parameters: ["category": categoryName])
    }

    // MARK: - Recurring Events

    static func logRecurringTemplateCreated(pattern: String, category: String) {
        logEvent("recurring_template_created", parameters: [
            "pattern": pattern,
            "category": category,
        ])
    }

    static func logRecurringTemplateToggled(isActive: Bool, category: String) {
        logEvent("recurring_template_toggled", parameters: [
            "is_active": isActive,
            "category": category,
        ])
    }

    static func logRecurringTemplateDeleted(category: String) {
        logEvent("recurring_template_deleted", parameters: ["category": category])
    }

    // MARK: - AI Parser Events

    static func logGeminiParseSuccess(confidence: Double, expenseCount: Int, language: String) {
        logEvent("gemini_parse_success", parameters: [
            "confidence": confidence,
            "expense_count": expenseCount,
            "language": language,
        ])
    }

    static func logGeminiParseFailed(errorReason: String, language: String) {
        logEvent("gemini_parse_failed", parameters: [
            "error_reason": errorReason,
            "language": language,
        ])
    }

    static func logGeminiLimitReached(remainingCount: Int) {
        logEvent("gemini_limit_reached", parameters: ["remaining_count": remainingCount])
    }

    // MARK: - Settings Events

    static func logLanguageChanged(from fromLang: String, to toLang: String) {
        logEvent("language_changed", parameters: ["from": fromLang, "to": toLang])
    }

    static func logCurrencyChanged(from fromCurrency: String, to toCurrency: String) {
        logEvent("currency_changed", parameters: ["from": fromCurrency, "to": toCurrency])
    }

    static func logThemeChanged(from fromTheme: String, to toTheme: String) {
        logEvent("theme_changed", parameters: ["from": fromTheme, "to": toTheme])
    }

    static func logOnboardingCompleted(language: String, currency: String) {
        logEvent("onboarding_completed", parameters: [
            "language": language,
            "currency": currency,
        ])
    }

    // MARK: - User Properties

    static func setLanguageProperty(_ language: String) {
        setUserProperty(name: "language", value: language)
    }

    static func setCurrencyProperty(_ currency: String) {
        setUserProperty(name: "currency", value: currency)
    }

    static func setThemeModeProperty(_ themeMode: String) {
        setUserProperty(name: "theme_mode", value: themeMode)
    }

    // MARK: - Helpers

    /// Privacy-safe amount bucketing
    static func getAmountRange(_ amount: Double) -> String {
        if amount < 10_000 { return "0-10k" }
        if amount < 100_000 { return "10k-100k" }
        if amount < 1_000_000 { return "100k-1m" }
        return "1m+"
    }

    static func getExpenseAgeDays(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
    }
}

// MARK: - Firebase Analytics Integration

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics

extension AnalyticsService {
    static func _initializeFirebase() {
        #if DEBUG
        Analytics.setAnalyticsCollectionEnabled(false)
        print("[Analytics] Disabled in DEBUG mode")
        #else
        Analytics.setAnalyticsCollectionEnabled(true)
        print("[Analytics] Firebase Analytics enabled")
        #endif
        isEnabled = true
    }

    static func _logFirebaseEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }

    static func _logFirebaseScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
        ])
    }

    static func _setFirebaseUserProperty(name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
#endif

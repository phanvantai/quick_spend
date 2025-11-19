import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics service for tracking user behavior and app performance
///
/// Provides methods to log events, screen views, and user properties
/// Privacy-aware: Never logs PII (amounts, descriptions, personal data)
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver _observer;

  FirebaseAnalyticsObserver get observer => _observer;

  /// Initialize Firebase Analytics
  Future<void> init() async {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);

    // Enable debug mode in debug builds for real-time event viewing in Firebase
    // Disable analytics collection in debug mode to save quota (optional - comment out to keep enabled)
    if (kDebugMode) {
      debugPrint('🔧 [Analytics] Running in DEBUG mode');
      // Option 1: Disable analytics in debug (recommended to save quota)
      await _analytics.setAnalyticsCollectionEnabled(false);
      debugPrint('✅ [Analytics] Analytics DISABLED in debug mode (events logged locally only)');

      // Option 2: Enable analytics with debug mode for real-time viewing (uncomment if needed)
      // await _analytics.setAnalyticsCollectionEnabled(true);
      // debugPrint('✅ [Analytics] Analytics enabled with debug mode for real-time viewing');
    } else {
      // Production/release mode - enable analytics
      await _analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('✅ [Analytics] Firebase Analytics initialized in RELEASE mode');
    }
  }

  /// Log a custom event
  ///
  /// Parameters:
  /// - [name]: Event name (use lowercase with underscores)
  /// - [parameters]: Optional event parameters (max 25 parameters, 100 chars per value)
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('📊 [Analytics] Event: $name ${parameters ?? ''}');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log event $name: $e');
    }
  }

  /// Log a screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('📱 [Analytics] Screen: $screenName');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to log screen view: $e');
    }
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('👤 [Analytics] User property: $name = $value');
    } catch (e) {
      debugPrint('❌ [Analytics] Failed to set user property: $e');
    }
  }

  // ============================================================================
  // SCREEN VIEW EVENTS
  // ============================================================================

  Future<void> logOnboardingScreen() => logScreenView(
        screenName: 'onboarding',
        screenClass: 'OnboardingScreen',
      );

  Future<void> logHomeScreen() => logScreenView(
        screenName: 'home',
        screenClass: 'HomeScreen',
      );

  Future<void> logReportScreen() => logScreenView(
        screenName: 'report',
        screenClass: 'ReportScreen',
      );

  Future<void> logSettingsScreen() => logScreenView(
        screenName: 'settings',
        screenClass: 'SettingsScreen',
      );

  Future<void> logExpenseFormScreen({required bool isEdit}) => logScreenView(
        screenName: isEdit ? 'expense_edit' : 'expense_add',
        screenClass: 'ExpenseFormScreen',
      );

  Future<void> logAllExpensesScreen() => logScreenView(
        screenName: 'all_expenses',
        screenClass: 'AllExpensesScreen',
      );

  Future<void> logCategoriesScreen() => logScreenView(
        screenName: 'categories',
        screenClass: 'CategoriesScreen',
      );

  Future<void> logCategoryFormScreen({required bool isEdit}) => logScreenView(
        screenName: isEdit ? 'category_edit' : 'category_add',
        screenClass: 'CategoryFormScreen',
      );

  Future<void> logRecurringExpensesScreen() => logScreenView(
        screenName: 'recurring_expenses',
        screenClass: 'RecurringExpensesScreen',
      );

  Future<void> logRecurringFormScreen({required bool isEdit}) => logScreenView(
        screenName: isEdit ? 'recurring_edit' : 'recurring_add',
        screenClass: 'RecurringExpenseFormScreen',
      );

  // ============================================================================
  // EXPENSE EVENTS
  // ============================================================================

  Future<void> logExpenseAdded({
    required String method, // 'voice' or 'manual'
    required String category,
    required String amountRange, // '0-10k', '10k-100k', '100k-1m', '1m+'
    required String language,
    String? transactionType, // 'income' or 'expense'
  }) =>
      logEvent(
        name: 'expense_added',
        parameters: {
          'method': method,
          'category': category,
          'amount_range': amountRange,
          'language': language,
          if (transactionType != null) 'transaction_type': transactionType,
        },
      );

  Future<void> logExpenseEdited({
    required List<String> fieldsChanged,
    required String category,
  }) =>
      logEvent(
        name: 'expense_edited',
        parameters: {
          'fields_changed': fieldsChanged.join(','),
          'category': category,
        },
      );

  Future<void> logExpenseDeleted({
    required String category,
    required int ageDays,
  }) =>
      logEvent(
        name: 'expense_deleted',
        parameters: {
          'category': category,
          'age_days': ageDays,
        },
      );

  // ============================================================================
  // VOICE INPUT EVENTS
  // ============================================================================

  Future<void> logVoiceInputStarted({required String language}) => logEvent(
        name: 'voice_input_started',
        parameters: {'language': language},
      );

  Future<void> logVoiceInputCompleted({
    required bool success,
    required int durationSeconds,
    required String language,
  }) =>
      logEvent(
        name: 'voice_input_completed',
        parameters: {
          'success': success ? 1 : 0, // Firebase Analytics requires num, not bool
          'duration_seconds': durationSeconds,
          'language': language,
        },
      );

  Future<void> logVoiceInputCancelled({required String language}) => logEvent(
        name: 'voice_input_cancelled',
        parameters: {'language': language},
      );

  // ============================================================================
  // CATEGORY EVENTS
  // ============================================================================

  Future<void> logCategoryCreated({required bool isCustom}) => logEvent(
        name: 'category_created',
        parameters: {'is_custom': isCustom},
      );

  Future<void> logCategoryEdited({required String categoryName}) => logEvent(
        name: 'category_edited',
        parameters: {'category': categoryName},
      );

  Future<void> logCategoryDeleted({required String categoryName}) => logEvent(
        name: 'category_deleted',
        parameters: {'category': categoryName},
      );

  // ============================================================================
  // RECURRING EXPENSE EVENTS
  // ============================================================================

  Future<void> logRecurringTemplateCreated({
    required String pattern, // 'monthly' or 'yearly'
    required String category,
  }) =>
      logEvent(
        name: 'recurring_template_created',
        parameters: {
          'pattern': pattern,
          'category': category,
        },
      );

  Future<void> logRecurringTemplateToggled({
    required bool isActive,
    required String category,
  }) =>
      logEvent(
        name: 'recurring_template_toggled',
        parameters: {
          'is_active': isActive,
          'category': category,
        },
      );

  Future<void> logRecurringTemplateDeleted({required String category}) =>
      logEvent(
        name: 'recurring_template_deleted',
        parameters: {'category': category},
      );

  // ============================================================================
  // IMPORT/EXPORT EVENTS
  // ============================================================================

  Future<void> logDataExported({
    required String format, // 'json'
    required int expenseCount,
  }) =>
      logEvent(
        name: 'data_exported',
        parameters: {
          'format': format,
          'expense_count': expenseCount,
        },
      );

  Future<void> logDataImported({
    required String format, // 'json'
    required int successCount,
    required int errorCount,
  }) =>
      logEvent(
        name: 'data_imported',
        parameters: {
          'format': format,
          'success_count': successCount,
          'error_count': errorCount,
        },
      );

  // ============================================================================
  // REPORT EVENTS
  // ============================================================================

  Future<void> logReportPeriodChanged({
    required String period, // 'today', 'week', 'month', 'year', 'custom'
  }) =>
      logEvent(
        name: 'report_period_changed',
        parameters: {'period': period},
      );

  Future<void> logChartTypeViewed({
    required String type, // 'donut', 'trend', 'calendar'
  }) =>
      logEvent(
        name: 'chart_type_viewed',
        parameters: {'type': type},
      );

  // ============================================================================
  // AI PARSER EVENTS
  // ============================================================================

  Future<void> logGeminiParseSuccess({
    required double confidence,
    required int expenseCount,
    required String language,
  }) =>
      logEvent(
        name: 'gemini_parse_success',
        parameters: {
          'confidence': confidence,
          'expense_count': expenseCount,
          'language': language,
        },
      );

  Future<void> logGeminiParseFailed({
    required String errorReason,
    required String language,
  }) =>
      logEvent(
        name: 'gemini_parse_failed',
        parameters: {
          'error_reason': errorReason,
          'language': language,
        },
      );

  Future<void> logGeminiLimitReached({required int remainingCount}) => logEvent(
        name: 'gemini_limit_reached',
        parameters: {'remaining_count': remainingCount},
      );

  Future<void> logFallbackParserUsed({
    required String reason, // 'gemini_unavailable', 'gemini_failed', 'limit_reached'
    required String language,
  }) =>
      logEvent(
        name: 'fallback_parser_used',
        parameters: {
          'reason': reason,
          'language': language,
        },
      );

  Future<void> logExpenseAutoCategorized({
    required String category,
    required double confidence,
  }) =>
      logEvent(
        name: 'expense_auto_categorized',
        parameters: {
          'category': category,
          'confidence': confidence,
        },
      );

  Future<void> logExpenseCategoryOverridden({
    required String fromCategory,
    required String toCategory,
  }) =>
      logEvent(
        name: 'expense_category_overridden',
        parameters: {
          'from_category': fromCategory,
          'to_category': toCategory,
        },
      );

  // ============================================================================
  // SETTINGS EVENTS
  // ============================================================================

  Future<void> logLanguageChanged({
    required String fromLanguage,
    required String toLanguage,
  }) =>
      logEvent(
        name: 'language_changed',
        parameters: {
          'from': fromLanguage,
          'to': toLanguage,
        },
      );

  Future<void> logCurrencyChanged({
    required String fromCurrency,
    required String toCurrency,
  }) =>
      logEvent(
        name: 'currency_changed',
        parameters: {
          'from': fromCurrency,
          'to': toCurrency,
        },
      );

  Future<void> logThemeChanged({
    required String fromTheme,
    required String toTheme,
  }) =>
      logEvent(
        name: 'theme_changed',
        parameters: {
          'from': fromTheme,
          'to': toTheme,
        },
      );

  Future<void> logDataCollectionToggled({required bool enabled}) => logEvent(
        name: 'data_collection_toggled',
        parameters: {'enabled': enabled ? 1 : 0}, // Firebase Analytics requires num, not bool
      );

  Future<void> logOnboardingCompleted({
    required String language,
    required String currency,
  }) =>
      logEvent(
        name: 'onboarding_completed',
        parameters: {
          'language': language,
          'currency': currency,
        },
      );

  // ============================================================================
  // USER PROPERTIES
  // ============================================================================

  Future<void> setLanguageProperty(String language) =>
      setUserProperty(name: 'language', value: language);

  Future<void> setCurrencyProperty(String currency) =>
      setUserProperty(name: 'currency', value: currency);

  Future<void> setThemeModeProperty(String themeMode) =>
      setUserProperty(name: 'theme_mode', value: themeMode);

  Future<void> setDataCollectionConsentProperty(bool consent) =>
      setUserProperty(name: 'data_collection_consent', value: consent.toString());

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get amount range bucket for privacy
  String getAmountRange(double amount) {
    if (amount < 10000) return '0-10k';
    if (amount < 100000) return '10k-100k';
    if (amount < 1000000) return '100k-1m';
    return '1m+';
  }

  /// Get age in days for expense
  int getExpenseAgeDays(DateTime expenseDate) {
    return DateTime.now().difference(expenseDate).inDays;
  }
}

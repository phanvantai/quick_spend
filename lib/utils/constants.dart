/// Application-wide constants and configuration values
///
/// This file centralizes all magic numbers and configuration values
/// used throughout the application for better maintainability.
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ========================================
  // User Configuration
  // ========================================

  /// Default user ID for local storage
  ///
  /// Since this is a local-only app (no cloud sync), we use a single
  /// consistent user ID for all expenses stored locally.
  static const String defaultUserId = 'local_user';

  // ========================================
  // API & Network Configuration
  // ========================================

  /// Timeout for Gemini AI API requests in seconds
  static const int geminiApiTimeoutSeconds = 30;

  /// Maximum number of retries for API requests
  static const int maxApiRetries = 3;

  /// Delay between API retries in milliseconds
  static const int apiRetryDelayMs = 1000;

  // ========================================
  // Voice Input Configuration
  // ========================================

  /// Minimum length of voice input to be considered valid
  static const int minVoiceInputLength = 2;

  /// Maximum length of voice input description
  static const int maxVoiceInputLength = 500;

  /// Delay after stopping voice recording in milliseconds
  static const int voiceStopDelayMs = 100;

  // ========================================
  // Expense & Transaction Limits
  // ========================================

  /// Maximum allowed expense amount (to prevent data corruption)
  static const double maxExpenseAmount = 999999999999.0; // ~1 trillion

  /// Minimum allowed expense amount
  static const double minExpenseAmount = 0.01;

  /// Maximum length of expense description
  static const int maxDescriptionLength = 500;

  /// Maximum length of category name
  static const int maxCategoryNameLength = 50;

  // ========================================
  // Recurring Expense Configuration
  // ========================================

  /// Maximum number of recurring expense instances to generate per cycle
  /// This prevents infinite loops or excessive database operations
  static const int maxRecurringInstancesPerGeneration = 100;

  /// Maximum years in the future to generate recurring expenses
  static const int maxRecurringYearsAhead = 5;

  // ========================================
  // Date & Time Configuration
  // ========================================

  /// Maximum years in the past for expense dates (for sanity checking)
  static const int maxYearsInPast = 10;

  /// Maximum years in the future for expense dates (for sanity checking)
  static const int maxYearsInFuture = 1;

  // ========================================
  // UI & UX Configuration
  // ========================================

  /// Default number of expenses to load per page (for pagination)
  static const int expensesPerPage = 50;

  /// Number of top expenses to show in reports
  static const int topExpensesCount = 5;

  /// Animation duration for standard transitions (milliseconds)
  static const int standardAnimationDurationMs = 300;

  /// Debounce duration for search input (milliseconds)
  static const int searchDebounceDurationMs = 500;

  // ========================================
  // CSV Import Configuration
  // ========================================

  /// Maximum file size for CSV import (in bytes) - 10 MB
  static const int maxCsvFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum number of rows to import from CSV
  static const int maxCsvRows = 10000;

  // ========================================
  // Database Configuration
  // ========================================

  /// Current database schema version
  static const int databaseVersion = 2;

  /// Database file name
  static const String databaseName = 'quick_spend.db';

  // ========================================
  // Confidence Thresholds
  // ========================================

  /// Minimum confidence score to consider parsing successful
  static const double minParsingConfidence = 0.5;

  /// Confidence threshold to show warning to user
  static const double confidenceWarningThreshold = 0.7;

  /// High confidence threshold (no warning needed)
  static const double highConfidenceThreshold = 0.9;

  // ========================================
  // Debug Configuration
  // ========================================

  /// Number of taps on settings logo to enable debug mode
  static const int debugModeActivationTaps = 5;

  /// Time window for debug mode activation taps (milliseconds)
  static const int debugModeActivationWindowMs = 3000;
}

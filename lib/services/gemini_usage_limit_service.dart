import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Service for tracking daily Gemini API usage limits
/// Daily limit is configurable via AppConstants.geminiDailyParsingLimit
class GeminiUsageLimitService {
  static const String _usageCountKey = 'gemini_daily_usage_count';
  static const String _lastResetDateKey = 'gemini_last_reset_date';

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetIfNewDay();
  }

  /// Ensure preferences are initialized
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  /// Check if we need to reset the counter for a new day
  Future<void> _checkAndResetIfNewDay() async {
    await _ensureInitialized();

    final lastResetDateStr = _prefs!.getString(_lastResetDateKey);
    final today = _getTodayString();

    if (lastResetDateStr != today) {
      // New day, reset counter
      debugPrint('🔄 [GeminiUsageLimit] New day detected, resetting counter');
      await _prefs!.setInt(_usageCountKey, 0);
      await _prefs!.setString(_lastResetDateKey, today);
    }
  }

  /// Get today's date as a string (YYYY-MM-DD)
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get current usage count for today
  Future<int> getUsageCount() async {
    await _checkAndResetIfNewDay();
    return _prefs!.getInt(_usageCountKey) ?? 0;
  }

  /// Get remaining parses for today
  Future<int> getRemainingCount() async {
    final used = await getUsageCount();
    return AppConstants.geminiDailyParsingLimit - used;
  }

  /// Check if limit has been reached
  Future<bool> hasReachedLimit() async {
    final count = await getUsageCount();
    return count >= AppConstants.geminiDailyParsingLimit;
  }

  /// Check if parse is allowed (not at limit)
  Future<bool> canParse() async {
    return !(await hasReachedLimit());
  }

  /// Increment usage count (call this after successful Gemini parse)
  Future<void> incrementUsage() async {
    await _checkAndResetIfNewDay();

    final currentCount = await getUsageCount();
    final newCount = currentCount + 1;

    await _prefs!.setInt(_usageCountKey, newCount);

    debugPrint(
      '📊 [GeminiUsageLimit] Usage: $newCount/${AppConstants.geminiDailyParsingLimit} (${AppConstants.geminiDailyParsingLimit - newCount} remaining)',
    );
  }

  /// Get the daily limit
  int get dailyLimit => AppConstants.geminiDailyParsingLimit;

  /// Get formatted usage string for display
  Future<String> getUsageString() async {
    final used = await getUsageCount();
    final remaining = AppConstants.geminiDailyParsingLimit - used;
    return '$remaining/${AppConstants.geminiDailyParsingLimit}';
  }

  /// Reset counter (for testing purposes)
  Future<void> resetCounter() async {
    await _ensureInitialized();
    await _prefs!.setInt(_usageCountKey, 0);
    await _prefs!.setString(_lastResetDateKey, _getTodayString());
    debugPrint('🔄 [GeminiUsageLimit] Counter manually reset');
  }
}

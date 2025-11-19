import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'subscription_service.dart';

/// Service for tracking daily Gemini API usage limits
/// Free tier: 5 parses/day (AppConstants.freeTierGeminiLimit)
/// Premium tier: Unlimited parses
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
  /// Returns -1 for unlimited (premium tier)
  Future<int> getRemainingCount() async {
    final isPremium = await SubscriptionService.isPremium();
    if (isPremium) return -1; // Unlimited

    final used = await getUsageCount();
    return AppConstants.freeTierGeminiLimit - used;
  }

  /// Check if limit has been reached
  /// Premium users never reach the limit
  Future<bool> hasReachedLimit() async {
    final isPremium = await SubscriptionService.isPremium();
    if (isPremium) return false; // Premium users have unlimited

    final count = await getUsageCount();
    return count >= AppConstants.freeTierGeminiLimit;
  }

  /// Check if parse is allowed (not at limit)
  /// Premium users can always parse
  Future<bool> canParse() async {
    final isPremium = await SubscriptionService.isPremium();
    if (isPremium) return true; // Premium users can always parse

    return !(await hasReachedLimit());
  }

  /// Increment usage count (call this after successful Gemini parse)
  /// Premium users don't have usage tracked
  Future<void> incrementUsage() async {
    final isPremium = await SubscriptionService.isPremium();
    if (isPremium) {
      debugPrint('✨ [GeminiUsageLimit] Premium user - unlimited usage');
      return; // Don't track usage for premium users
    }

    await _checkAndResetIfNewDay();

    final currentCount = await getUsageCount();
    final newCount = currentCount + 1;

    await _prefs!.setInt(_usageCountKey, newCount);

    debugPrint(
      '📊 [GeminiUsageLimit] Usage: $newCount/${AppConstants.freeTierGeminiLimit} (${AppConstants.freeTierGeminiLimit - newCount} remaining)',
    );
  }

  /// Get the daily limit based on subscription tier
  Future<int> getDailyLimit() async {
    final isPremium = await SubscriptionService.isPremium();
    return isPremium
        ? AppConstants.premiumTierGeminiLimit
        : AppConstants.freeTierGeminiLimit;
  }

  /// Get formatted usage string for display
  /// Shows "Unlimited" for premium users
  Future<String> getUsageString() async {
    final isPremium = await SubscriptionService.isPremium();
    if (isPremium) return 'Unlimited';

    final used = await getUsageCount();
    final remaining = AppConstants.freeTierGeminiLimit - used;
    return '$remaining/${AppConstants.freeTierGeminiLimit}';
  }

  /// Reset counter (for testing purposes)
  Future<void> resetCounter() async {
    await _ensureInitialized();
    await _prefs!.setInt(_usageCountKey, 0);
    await _prefs!.setString(_lastResetDateKey, _getTodayString());
    debugPrint('🔄 [GeminiUsageLimit] Counter manually reset');
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_status.dart';
import '../models/subscription_tier.dart';

/// Service for managing subscription state
class SubscriptionService {
  static const String _subscriptionKey = 'subscription_status';

  /// Get current subscription status
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_subscriptionKey);

    if (jsonString == null) {
      return SubscriptionStatus.free();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final status = SubscriptionStatus.fromJson(json);

      // Check if expired
      if (status.isExpired) {
        // Downgrade to free
        await saveSubscriptionStatus(SubscriptionStatus.free());
        return SubscriptionStatus.free();
      }

      return status;
    } catch (e) {
      print('❌ Error loading subscription status: $e');
      return SubscriptionStatus.free();
    }
  }

  /// Save subscription status
  static Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(status.toJson());
    await prefs.setString(_subscriptionKey, jsonString);
    print('💾 Subscription status saved: ${status.tier.displayName}');
  }

  /// Upgrade to premium (mock for now)
  static Future<SubscriptionStatus> upgradeToPremium({
    DateTime? expiryDate,
    String platform = 'mock',
  }) async {
    final status = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      expiryDate: expiryDate,
      platform: platform,
      purchaseDate: DateTime.now(),
    );
    await saveSubscriptionStatus(status);
    print('🎉 Upgraded to premium!');
    return status;
  }

  /// Downgrade to free
  static Future<SubscriptionStatus> downgradeToFree() async {
    final status = SubscriptionStatus.free();
    await saveSubscriptionStatus(status);
    print('📉 Downgraded to free');
    return status;
  }

  /// Check if user has premium subscription
  static Future<bool> isPremium() async {
    final status = await getSubscriptionStatus();
    return status.isPremium;
  }

  /// Check if user can use a feature
  static Future<bool> canUseFeature(String feature) async {
    final status = await getSubscriptionStatus();

    // Premium users can use all features
    if (status.isPremium) return true;

    // Free users have restrictions on some features
    switch (feature) {
      case 'unlimited_gemini':
      case 'unlimited_voice':
      case 'unlimited_recurring':
      case 'advanced_reports':
        return false;
      default:
        return true; // Other features available to all
    }
  }

  /// Clear subscription data (for testing)
  static Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscriptionKey);
    print('🗑️ Subscription data cleared');
  }
}

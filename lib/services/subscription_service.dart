import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_status.dart';
import '../models/subscription_tier.dart';
import 'revenue_cat_service.dart';

/// Service for managing subscription state
///
/// Integrates with RevenueCat for real subscription management.
/// Uses SharedPreferences as a local cache for offline access.
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
      debugPrint('❌ Error loading subscription status: $e');
      return SubscriptionStatus.free();
    }
  }

  /// Save subscription status
  static Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(status.toJson());
    await prefs.setString(_subscriptionKey, jsonString);
    debugPrint('💾 Subscription status saved: ${status.tier.displayName}');
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
    debugPrint('🎉 Upgraded to premium!');
    return status;
  }

  /// Downgrade to free
  static Future<SubscriptionStatus> downgradeToFree() async {
    final status = SubscriptionStatus.free();
    await saveSubscriptionStatus(status);
    debugPrint('📉 Downgraded to free');
    return status;
  }

  /// Check if user has premium subscription
  ///
  /// Checks RevenueCat first (source of truth), falls back to local cache if offline.
  static Future<bool> isPremium() async {
    try {
      // Try to get real status from RevenueCat
      final isPremiumRC = await RevenueCatService.instance.isPremium();

      // Sync local cache with RevenueCat status
      if (isPremiumRC) {
        // User is premium according to RevenueCat
        final currentStatus = await getSubscriptionStatus();
        if (!currentStatus.isPremium) {
          // Local cache is outdated, update it
          await _syncFromRevenueCat();
        }
      } else {
        // User is NOT premium according to RevenueCat
        final currentStatus = await getSubscriptionStatus();
        if (currentStatus.isPremium) {
          // Local cache shows premium but RevenueCat says no, downgrade
          await downgradeToFree();
        }
      }

      return isPremiumRC;
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Failed to check RevenueCat, using local cache: $e');
      // Fallback to local cache if RevenueCat fails (offline, etc.)
      final status = await getSubscriptionStatus();
      return status.isPremium;
    }
  }

  /// Sync subscription status from RevenueCat to local storage
  ///
  /// Call this after successful purchase or when app starts.
  static Future<void> syncFromRevenueCat() async {
    await _syncFromRevenueCat();
  }

  /// Internal method to sync from RevenueCat
  static Future<void> _syncFromRevenueCat() async {
    try {
      debugPrint('🔄 [SubscriptionService] Syncing from RevenueCat...');

      final customerInfo = await RevenueCatService.instance.getCustomerInfo();
      if (customerInfo == null) {
        debugPrint('⚠️ [SubscriptionService] No customer info available');
        return;
      }

      final premiumEntitlement = customerInfo.entitlements.all[RevenueCatService.premiumEntitlementId];

      if (premiumEntitlement != null && premiumEntitlement.isActive) {
        // User has active premium subscription
        final expiryDate = premiumEntitlement.expirationDate != null
            ? DateTime.parse(premiumEntitlement.expirationDate!)
            : null;

        final status = SubscriptionStatus(
          tier: SubscriptionTier.premium,
          expiryDate: expiryDate,
          platform: customerInfo.originalAppUserId.contains('apple') ? 'apple' : 'google',
          purchaseDate: DateTime.now(), // We don't have exact purchase date from RevenueCat
        );

        await saveSubscriptionStatus(status);
        debugPrint('✅ [SubscriptionService] Synced: Premium until ${expiryDate ?? "forever"}');
      } else {
        // No active premium subscription
        await downgradeToFree();
        debugPrint('✅ [SubscriptionService] Synced: Free tier');
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Failed to sync from RevenueCat: $e');
    }
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
    debugPrint('🗑️ Subscription data cleared');
  }
}

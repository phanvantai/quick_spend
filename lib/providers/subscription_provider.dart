import 'package:flutter/foundation.dart';
import '../models/subscription_status.dart';
import '../models/subscription_tier.dart';
import '../services/subscription_service.dart';

/// Provider for managing subscription state
class SubscriptionProvider with ChangeNotifier {
  SubscriptionStatus _status = SubscriptionStatus.free();

  SubscriptionStatus get status => _status;
  SubscriptionTier get tier => _status.tier;
  bool get isPremium => _status.isPremium;
  bool get isFree => !_status.isPremium;

  /// Initialize subscription status
  Future<void> initialize() async {
    _status = await SubscriptionService.getSubscriptionStatus();
    debugPrint('💳 Subscription initialized: ${_status.tier.displayName}');
    notifyListeners();
  }

  /// Upgrade to premium
  Future<void> upgradeToPremium({
    DateTime? expiryDate,
    String platform = 'mock',
  }) async {
    _status = await SubscriptionService.upgradeToPremium(
      expiryDate: expiryDate,
      platform: platform,
    );
    notifyListeners();
    debugPrint('🎉 Upgraded to premium in provider');
  }

  /// Downgrade to free
  Future<void> downgradeToFree() async {
    _status = await SubscriptionService.downgradeToFree();
    notifyListeners();
    debugPrint('📉 Downgraded to free in provider');
  }

  /// Check if user can use a feature
  bool canUseFeature(String feature) {
    // Premium users can use all features
    if (isPremium) return true;

    // Free users have restrictions
    switch (feature) {
      case 'unlimited_gemini':
      case 'unlimited_voice':
      case 'unlimited_recurring':
      case 'advanced_reports':
        return false;
      default:
        return true;
    }
  }

  /// Refresh subscription status (check for expiry)
  Future<void> refresh() async {
    _status = await SubscriptionService.getSubscriptionStatus();
    notifyListeners();
  }

  /// Clear subscription (for testing)
  Future<void> clearSubscription() async {
    await SubscriptionService.clearSubscription();
    _status = SubscriptionStatus.free();
    notifyListeners();
  }
}

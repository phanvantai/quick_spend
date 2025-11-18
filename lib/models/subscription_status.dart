import 'subscription_tier.dart';

/// Subscription status model
class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? expiryDate;
  final String? platform; // 'ios', 'android', 'mock'
  final DateTime? purchaseDate;

  SubscriptionStatus({
    required this.tier,
    this.expiryDate,
    this.platform,
    this.purchaseDate,
  });

  /// Check if subscription is active
  bool get isActive {
    if (tier == SubscriptionTier.free) return true;
    if (expiryDate == null) return true; // Lifetime premium
    return DateTime.now().isBefore(expiryDate!);
  }

  /// Check if subscription is expired
  bool get isExpired {
    if (tier == SubscriptionTier.free) return false;
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Check if premium
  bool get isPremium => tier.isPremium && isActive;

  /// Days until expiry
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'tier': tier.toStorageString(),
      'expiryDate': expiryDate?.toIso8601String(),
      'platform': platform,
      'purchaseDate': purchaseDate?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: SubscriptionTier.fromString(json['tier'] ?? 'free'),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      platform: json['platform'],
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'])
          : null,
    );
  }

  /// Create default free subscription
  factory SubscriptionStatus.free() {
    return SubscriptionStatus(tier: SubscriptionTier.free);
  }

  /// Create mock premium subscription (for testing)
  factory SubscriptionStatus.mockPremium({DateTime? expiryDate}) {
    return SubscriptionStatus(
      tier: SubscriptionTier.premium,
      expiryDate: expiryDate,
      platform: 'mock',
      purchaseDate: DateTime.now(),
    );
  }

  /// Copy with
  SubscriptionStatus copyWith({
    SubscriptionTier? tier,
    DateTime? expiryDate,
    String? platform,
    DateTime? purchaseDate,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      expiryDate: expiryDate ?? this.expiryDate,
      platform: platform ?? this.platform,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(tier: ${tier.displayName}, isActive: $isActive, expiryDate: $expiryDate)';
  }
}

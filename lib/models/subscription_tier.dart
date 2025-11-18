/// Subscription tier enum for the app
enum SubscriptionTier {
  free,
  premium;

  /// Display name for the tier
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  /// Check if tier is premium
  bool get isPremium => this == SubscriptionTier.premium;

  /// Check if tier is free
  bool get isFree => this == SubscriptionTier.free;

  /// Convert from string
  static SubscriptionTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  /// Convert to string for storage
  String toStorageString() {
    return name;
  }
}

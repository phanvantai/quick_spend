import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Service for managing subscriptions via RevenueCat
///
/// Handles product fetching, purchases, subscription status checks,
/// and restoration of purchases.
class RevenueCatService {
  // Private constructor for singleton pattern
  RevenueCatService._();

  /// Singleton instance
  static final RevenueCatService instance = RevenueCatService._();

  /// RevenueCat API Keys
  /// Get these from: RevenueCat Dashboard → Project Settings → API Keys
  /// Note: These are PUBLIC SDK keys (safe to commit to repository)
  static const String _appleApiKey = 'appl_uvXTlqDdZAaoRtAEZIIFxiPkloh';
  static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE'; // TODO: Add when setting up Google Play

  /// Entitlement identifier (must match RevenueCat dashboard)
  static const String premiumEntitlementId = 'premium';

  /// Whether RevenueCat has been initialized
  bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  ///
  /// Call this once at app startup before using any other RevenueCat features.
  /// Uses different API keys for iOS and Android.
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      debugPrint('✅ [RevenueCat] Already initialized');
      return;
    }

    try {
      debugPrint('🔄 [RevenueCat] Initializing...');

      // Configure SDK with optional user ID
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? _appleApiKey
          : defaultTargetPlatform == TargetPlatform.android
              ? _googleApiKey
              : null;

      if (apiKey == null) {
        debugPrint('⚠️ [RevenueCat] Unsupported platform');
        return;
      }

      // Create configuration
      final configuration = PurchasesConfiguration(apiKey);

      // Set user ID if provided
      if (userId != null) {
        configuration.appUserID = userId;
      }

      // Initialize
      await Purchases.configure(configuration);

      // Enable debug logs in development
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      _isInitialized = true;
      debugPrint('✅ [RevenueCat] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [RevenueCat] Initialization failed: $e');
      rethrow;
    }
  }

  /// Get available subscription offerings
  ///
  /// Returns null if no offerings are available or if there's an error.
  /// The "default" offering contains your configured subscription packages.
  Future<Offerings?> getOfferings() async {
    try {
      debugPrint('🔄 [RevenueCat] Fetching offerings...');
      final offerings = await Purchases.getOfferings();

      if (offerings.current != null) {
        debugPrint('✅ [RevenueCat] Found ${offerings.current!.availablePackages.length} packages');
        for (final package in offerings.current!.availablePackages) {
          debugPrint('  📦 Package: ${package.identifier}');
          debugPrint('     Product: ${package.storeProduct.identifier}');
          debugPrint('     Price: ${package.storeProduct.priceString}');
          debugPrint('     Title: ${package.storeProduct.title}');
        }
        return offerings;
      } else {
        debugPrint('⚠️ [RevenueCat] No current offering found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to fetch offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  ///
  /// Returns the updated CustomerInfo if successful.
  /// Throws PlatformException if purchase fails or is cancelled.
  Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      debugPrint('🔄 [RevenueCat] Purchasing package: ${package.identifier}');
      final purchaserInfo = await Purchases.purchasePackage(package);
      debugPrint('✅ [RevenueCat] Purchase successful');
      return purchaserInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Purchase failed: $e');
      rethrow;
    }
  }

  /// Check if user has active premium subscription
  ///
  /// Returns true if the 'premium' entitlement is active.
  Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.all[premiumEntitlementId]?.isActive ?? false;
      debugPrint('🔍 [RevenueCat] Premium status: $isPremium');
      return isPremium;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to check premium status: $e');
      return false;
    }
  }

  /// Get customer info (subscription status, entitlements, etc.)
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      debugPrint('✅ [RevenueCat] Got customer info');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to get customer info: $e');
      return null;
    }
  }

  /// Restore previous purchases
  ///
  /// Call this when user taps "Restore Purchases" button.
  /// Returns the updated CustomerInfo.
  Future<CustomerInfo> restorePurchases() async {
    try {
      debugPrint('🔄 [RevenueCat] Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('✅ [RevenueCat] Purchases restored');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to restore purchases: $e');
      rethrow;
    }
  }

  /// Login with user ID
  ///
  /// Call this when user logs in to sync their subscription across devices.
  Future<CustomerInfo> login(String userId) async {
    try {
      debugPrint('🔄 [RevenueCat] Logging in user: $userId');
      final customerInfo = await Purchases.logIn(userId);
      debugPrint('✅ [RevenueCat] User logged in');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to login: $e');
      rethrow;
    }
  }

  /// Logout current user
  ///
  /// Call this when user logs out.
  Future<CustomerInfo> logout() async {
    try {
      debugPrint('🔄 [RevenueCat] Logging out user');
      final customerInfo = await Purchases.logOut();
      debugPrint('✅ [RevenueCat] User logged out');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to logout: $e');
      rethrow;
    }
  }

  /// Set up listener for subscription status changes
  ///
  /// This is useful for detecting when a subscription is purchased, renewed, or expires.
  void addCustomerInfoUpdateListener(
    void Function(CustomerInfo customerInfo) listener,
  ) {
    Purchases.addCustomerInfoUpdateListener(listener);
    debugPrint('✅ [RevenueCat] Customer info listener added');
  }

  /// Remove listener
  void removeCustomerInfoUpdateListener(
    void Function(CustomerInfo customerInfo) listener,
  ) {
    Purchases.removeCustomerInfoUpdateListener(listener);
    debugPrint('✅ [RevenueCat] Customer info listener removed');
  }
}

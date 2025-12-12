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
  static const String _googleApiKey =
      'YOUR_GOOGLE_API_KEY_HERE'; // TODO: Add when setting up Google Play

  /// Entitlement identifier (must match RevenueCat dashboard)
  static const String premiumEntitlementId = 'premium';

  /// Whether RevenueCat has been initialized
  bool _isInitialized = false;

  /// Whether the current platform is supported (iOS only for now)
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Initialize RevenueCat SDK
  ///
  /// Call this once at app startup before using any other RevenueCat features.
  /// Currently only supports iOS. Android support can be added when Google Play is configured.
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      debugPrint('✅ [RevenueCat] Already initialized');
      return;
    }

    // Check if platform is supported
    if (!isSupported) {
      debugPrint('⚠️ [RevenueCat] Platform not supported: ${defaultTargetPlatform.name}');
      return;
    }

    try {
      debugPrint('🔄 [RevenueCat] Initializing...');

      // Get API key for current platform
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? _appleApiKey
          : _googleApiKey;

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
  /// Returns null if no offerings are available, platform unsupported, or if there's an error.
  /// The "default" offering contains your configured subscription packages.
  Future<Offerings?> getOfferings() async {
    if (!isSupported || !_isInitialized) {
      debugPrint('⚠️ [RevenueCat] Not available on this platform');
      return null;
    }

    try {
      debugPrint('🔄 [RevenueCat] Fetching offerings...');
      final offerings = await Purchases.getOfferings();

      if (offerings.current != null) {
        debugPrint(
          '✅ [RevenueCat] Found ${offerings.current!.availablePackages.length} packages',
        );
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
  /// Throws Exception if platform unsupported or purchase fails.
  Future<PurchaseResult> purchasePackage(Package package) async {
    if (!isSupported || !_isInitialized) {
      throw Exception('RevenueCat not available on this platform');
    }

    try {
      debugPrint('🔄 [RevenueCat] Purchasing package: ${package.identifier}');
      final purchaseParams = PurchaseParams.package(package);
      final purchaserInfo = await Purchases.purchase(purchaseParams);
      debugPrint('✅ [RevenueCat] Purchase successful $purchaserInfo');
      return purchaserInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Purchase failed: $e');
      rethrow;
    }
  }

  /// Check if user has active premium subscription
  ///
  /// Returns false if platform unsupported or 'premium' entitlement is not active.
  Future<bool> isPremium() async {
    if (!isSupported || !_isInitialized) {
      debugPrint('⚠️ [RevenueCat] Not available on this platform');
      return false;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium =
          customerInfo.entitlements.all[premiumEntitlementId]?.isActive ??
          false;
      debugPrint('🔍 [RevenueCat] Premium status: $isPremium');
      return isPremium;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Failed to check premium status: $e');
      return false;
    }
  }

  /// Get customer info (subscription status, entitlements, etc.)
  ///
  /// Returns null if platform unsupported or error occurs.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!isSupported || !_isInitialized) {
      debugPrint('⚠️ [RevenueCat] Not available on this platform');
      return null;
    }

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
  /// Throws Exception if platform unsupported or restoration fails.
  Future<CustomerInfo> restorePurchases() async {
    if (!isSupported || !_isInitialized) {
      throw Exception('RevenueCat not available on this platform');
    }

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
      final result = await Purchases.logIn(userId);
      debugPrint('✅ [RevenueCat] User logged in');
      return result.customerInfo;
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

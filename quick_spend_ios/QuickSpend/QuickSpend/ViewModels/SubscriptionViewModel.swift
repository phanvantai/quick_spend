import Foundation

/// Subscription state management
/// NOTE: Requires RevenueCat SDK added via SPM. Until then, all users are on free tier.
@Observable
final class SubscriptionViewModel {
    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = false

    /// Feature gating
    var geminiDailyLimit: Int {
        isPro ? 999 : AppConstants.freeTierGeminiLimit
    }

    var recurringTemplatesLimit: Int {
        isPro ? 999 : AppConstants.freeTierRecurringTemplatesLimit
    }

    var reportDaysLimit: Int {
        isPro ? 365 * 10 : AppConstants.freeTierReportDaysLimit
    }

    /// Check if user can add more recurring templates
    func canAddRecurringTemplate(currentCount: Int) -> Bool {
        isPro || currentCount < recurringTemplatesLimit
    }

    // MARK: - Initialization

    /// Initialize RevenueCat and check subscription status
    func initialize() {
        #if canImport(RevenueCat)
        _initializeRevenueCat()
        #else
        print("[Subscription] RevenueCat SDK not available. Add via SPM to enable subscriptions.")
        isPro = false
        #endif
    }

    /// Restore purchases
    func restorePurchases() async {
        #if canImport(RevenueCat)
        await _restorePurchases()
        #else
        print("[Subscription] RevenueCat not available")
        #endif
    }

    /// Purchase monthly subscription
    func purchaseMonthly() async -> Bool {
        #if canImport(RevenueCat)
        return await _purchasePackage(identifier: "monthly")
        #else
        print("[Subscription] RevenueCat not available")
        return false
        #endif
    }

    /// Purchase yearly subscription
    func purchaseYearly() async -> Bool {
        #if canImport(RevenueCat)
        return await _purchasePackage(identifier: "yearly")
        #else
        print("[Subscription] RevenueCat not available")
        return false
        #endif
    }

    /// Refresh subscription status
    func refreshStatus() async {
        #if canImport(RevenueCat)
        await _refreshCustomerInfo()
        #endif
    }
}

// MARK: - RevenueCat Integration

#if canImport(RevenueCat)
import RevenueCat

extension SubscriptionViewModel {
    func _initializeRevenueCat() {
        // Configure RevenueCat - API key should be set in app configuration
        // Purchases.configure(withAPIKey: "your_api_key")
        print("[Subscription] RevenueCat initialized")
        Task { await _refreshCustomerInfo() }
    }

    func _refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
            print("[Subscription] Pro status: \(isPro)")
        } catch {
            print("[Subscription] Error checking status: \(error)")
        }
    }

    func _restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            print("[Subscription] Restore error: \(error)")
        }
    }

    func _purchasePackage(identifier: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.package(identifier: identifier) else {
                print("[Subscription] Package '\(identifier)' not found")
                return false
            }
            let result = try await Purchases.shared.purchase(package: package)
            isPro = result.customerInfo.entitlements["pro"]?.isActive == true
            return isPro
        } catch {
            print("[Subscription] Purchase error: \(error)")
            return false
        }
    }
}
#endif

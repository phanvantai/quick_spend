import Foundation

// MARK: - Subscription Provider Protocol

/// Protocol abstracting subscription backend for testability
protocol SubscriptionProvider: Sendable {
    func configure()
    func checkPremiumStatus() async -> Bool
    func loadPrices() async -> (monthly: String?, yearly: String?)
    func purchase(monthly: Bool) async -> Bool
    func restorePurchases() async -> Bool
}

/// No-op provider used when RevenueCat SDK is not available
struct NoOpSubscriptionProvider: SubscriptionProvider {
    func configure() {}
    func checkPremiumStatus() async -> Bool { false }
    func loadPrices() async -> (monthly: String?, yearly: String?) { (nil, nil) }
    func purchase(monthly: Bool) async -> Bool { false }
    func restorePurchases() async -> Bool { false }
}

/// Subscription state management
/// NOTE: Requires RevenueCat SDK added via SPM. Until then, all users are on free tier.
@Observable
final class SubscriptionViewModel {
    private(set) var isPremium: Bool = false
    private(set) var isLoading: Bool = false

    /// Localized price strings loaded from RevenueCat
    private(set) var monthlyPriceDisplay: String?
    private(set) var yearlyPriceDisplay: String?

    private let provider: SubscriptionProvider

    /// RevenueCat API key (public SDK key, safe to commit)
    static let appleApiKey = "appl_uvXTlqDdZAaoRtAEZIIFxiPkloh"

    /// Entitlement identifier (must match RevenueCat dashboard)
    static let premiumEntitlementId = "premium"

    init(provider: SubscriptionProvider? = nil) {
        if let provider {
            self.provider = provider
        } else {
            #if canImport(RevenueCat)
            self.provider = RevenueCatProvider()
            #else
            self.provider = NoOpSubscriptionProvider()
            #endif
        }
    }

    /// Feature gating
    var geminiDailyLimit: Int {
        isPremium ? 999 : AppConstants.freeTierGeminiLimit
    }

    var recurringTemplatesLimit: Int {
        isPremium ? 999 : AppConstants.freeTierRecurringTemplatesLimit
    }

    var reportDaysLimit: Int {
        isPremium ? 365 * 10 : AppConstants.freeTierReportDaysLimit
    }

    /// Check if user can add more recurring templates
    func canAddRecurringTemplate(currentCount: Int) -> Bool {
        isPremium || currentCount < recurringTemplatesLimit
    }

    // MARK: - Initialization

    /// Initialize subscription provider and check status
    func initialize() {
        provider.configure()
        Task {
            isPremium = await provider.checkPremiumStatus()
            let prices = await provider.loadPrices()
            monthlyPriceDisplay = prices.monthly
            yearlyPriceDisplay = prices.yearly
        }
    }

    /// Load offerings and cache localized prices
    func loadOfferings() async {
        let prices = await provider.loadPrices()
        monthlyPriceDisplay = prices.monthly
        yearlyPriceDisplay = prices.yearly
    }

    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        isPremium = await provider.restorePurchases()
    }

    /// Purchase monthly subscription
    func purchaseMonthly() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let success = await provider.purchase(monthly: true)
        if success { isPremium = true }
        return success
    }

    /// Purchase yearly subscription
    func purchaseYearly() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let success = await provider.purchase(monthly: false)
        if success { isPremium = true }
        return success
    }

    /// Refresh subscription status
    func refreshStatus() async {
        isPremium = await provider.checkPremiumStatus()
    }

    // MARK: - Test Helpers

    /// Set premium status directly (for testing)
    func _setPremium(_ value: Bool) {
        isPremium = value
    }
}

// MARK: - RevenueCat Integration

#if canImport(RevenueCat)
import RevenueCat

/// Real RevenueCat-backed subscription provider
struct RevenueCatProvider: SubscriptionProvider {
    func configure() {
        Purchases.logLevel = .error
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: SubscriptionViewModel.appleApiKey)
        print("[Subscription] RevenueCat configured with API key: \(SubscriptionViewModel.appleApiKey.prefix(10))...")
    }

    func checkPremiumStatus() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Premium status: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Error checking status: \(error.localizedDescription)")
            return false
        }
    }

    func loadPrices() async -> (monthly: String?, yearly: String?) {
        print("[Subscription] Loading offerings...")
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                print("[Subscription] WARNING: No current offering found")
                return (nil, nil)
            }
            let monthly = current.monthly?.storeProduct.localizedPriceString
            let yearly = current.annual?.storeProduct.localizedPriceString
            print("[Subscription] Prices loaded — monthly: \(monthly ?? "nil"), yearly: \(yearly ?? "nil")")
            return (monthly, yearly)
        } catch {
            print("[Subscription] ERROR loading offerings: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    func purchase(monthly: Bool) async -> Bool {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                print("[Subscription] ERROR: No current offering available for purchase")
                return false
            }
            let package = monthly ? current.monthly : current.annual
            guard let package else {
                print("[Subscription] ERROR: Package not found in offering")
                return false
            }
            let result = try await Purchases.shared.purchase(package: package)
            let isPremium = result.customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Purchase completed. Premium: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Purchase error: \(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Restore completed. Premium: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Restore error: \(error.localizedDescription)")
            return false
        }
    }
}
#endif

import Foundation
import StoreKit

// MARK: - Subscription Provider Protocol

/// Protocol abstracting subscription backend for testability
protocol SubscriptionProvider: Sendable {
    func configure()
    func checkPremiumStatus() async -> Bool
    func loadPrices() async -> (monthly: String?, yearly: String?)
    func purchase(monthly: Bool) async -> Bool
    func restorePurchases() async -> Bool
    /// Sends the device's App Store transactions to the backend without a
    /// sign-in prompt. Returns the premium status afterwards.
    func syncPurchases() async -> Bool
}

/// No-op provider used when RevenueCat SDK is not available
struct NoOpSubscriptionProvider: SubscriptionProvider {
    func configure() {}
    func checkPremiumStatus() async -> Bool { false }
    func loadPrices() async -> (monthly: String?, yearly: String?) { (nil, nil) }
    func purchase(monthly: Bool) async -> Bool { false }
    func restorePurchases() async -> Bool { false }
    func syncPurchases() async -> Bool { false }
}

// MARK: - StoreKit Entitlements

/// Asks the App Store (on device) whether the user has an active subscription.
protocol StoreEntitlementChecking: Sendable {
    func hasActiveSubscription() async -> Bool
}

/// Reads StoreKit 2's signed current entitlements. Every auto-renewable product
/// in this app unlocks Premium, so any active one counts.
struct StoreKitEntitlementChecker: StoreEntitlementChecking {
    func hasActiveSubscription() async -> Bool {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productType == .autoRenewable && transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
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
    private let storeEntitlements: StoreEntitlementChecking

    /// RevenueCat API key (public SDK key, safe to commit)
    static let appleApiKey = "appl_uvXTlqDdZAaoRtAEZIIFxiPkloh"

    /// Entitlement identifier (must match RevenueCat dashboard)
    static let premiumEntitlementId = "premium"

    init(
        provider: SubscriptionProvider? = nil,
        storeEntitlements: StoreEntitlementChecking = StoreKitEntitlementChecker()
    ) {
        self.storeEntitlements = storeEntitlements
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

    /// Check if user can add more recurring templates
    func canAddRecurringTemplate(currentCount: Int) -> Bool {
        isPremium || currentCount < recurringTemplatesLimit
    }

    // MARK: - Initialization

    /// Initialize subscription provider and check status
    func initialize() {
        provider.configure()
        Task {
            await refreshStatus()
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
        if await provider.restorePurchases() {
            isPremium = true
        } else {
            await refreshStatus()
        }
    }

    /// Purchase monthly subscription
    func purchaseMonthly() async -> Bool {
        await purchase(monthly: true)
    }

    /// Purchase yearly subscription
    func purchaseYearly() async -> Bool {
        await purchase(monthly: false)
    }

    /// A failed purchase can still mean the user is subscribed: the App Store
    /// answers "already subscribed" for an active plan. Check before reporting failure.
    private func purchase(monthly: Bool) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        if await provider.purchase(monthly: monthly) {
            isPremium = true
        } else {
            await refreshStatus()
        }
        return isPremium
    }

    /// Refresh subscription status. RevenueCat can report an active subscriber
    /// as free (stale cache, renewal it has not seen yet), so StoreKit's signed
    /// entitlements on the device have the final say, and RevenueCat is resynced.
    func refreshStatus() async {
        if await provider.checkPremiumStatus() {
            isPremium = true
            return
        }
        isPremium = await storeEntitlements.hasActiveSubscription()
        if isPremium {
            _ = await provider.syncPurchases()
        }
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

    /// Fetches from the server: the default policy returns the cached
    /// CustomerInfo from the last session even when stale. The cache is only
    /// used when the server cannot be reached.
    func checkPremiumStatus() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
            let isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Premium status: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Error checking status: \(error.localizedDescription)")
            let cached = try? await Purchases.shared.customerInfo(fetchPolicy: .fromCacheOnly)
            return cached?.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
        }
    }

    func syncPurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.syncPurchases()
            let isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Sync completed. Premium: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Sync error: \(error.localizedDescription)")
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

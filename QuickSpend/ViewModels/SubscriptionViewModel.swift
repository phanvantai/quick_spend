import Foundation

/// Subscription state management
/// NOTE: Requires RevenueCat SDK added via SPM. Until then, all users are on free tier.
@Observable
final class SubscriptionViewModel {
    private(set) var isPremium: Bool = false
    private(set) var isLoading: Bool = false

    /// Localized price strings loaded from RevenueCat
    private(set) var monthlyPriceDisplay: String?
    private(set) var yearlyPriceDisplay: String?

    /// RevenueCat API key (public SDK key, safe to commit)
    private static let appleApiKey = "appl_uvXTlqDdZAaoRtAEZIIFxiPkloh"

    /// Entitlement identifier (must match RevenueCat dashboard)
    private static let premiumEntitlementId = "premium"

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

    /// Initialize RevenueCat and check subscription status
    func initialize() {
        #if canImport(RevenueCat)
        _initializeRevenueCat()
        #else
        print("[Subscription] RevenueCat SDK not available. Add via SPM to enable subscriptions.")
        isPremium = false
        #endif
    }

    /// Load offerings and cache localized prices
    func loadOfferings() async {
        #if canImport(RevenueCat)
        await _loadOfferings()
        #else
        print("[Subscription] RevenueCat not available — cannot load offerings")
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
        return await _purchasePackage(packageType: .monthly)
        #else
        print("[Subscription] RevenueCat not available")
        return false
        #endif
    }

    /// Purchase yearly subscription
    func purchaseYearly() async -> Bool {
        #if canImport(RevenueCat)
        return await _purchasePackage(packageType: .annual)
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
        Purchases.logLevel = .error
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: SubscriptionViewModel.appleApiKey)
        print("[Subscription] RevenueCat configured with API key: \(SubscriptionViewModel.appleApiKey.prefix(10))...")
        Task {
            await _refreshCustomerInfo()
            await _loadOfferings()
        }
    }

    func _loadOfferings() async {
        print("[Subscription] Loading offerings...")
        do {
            let offerings = try await Purchases.shared.offerings()

            if let current = offerings.current {
                print("[Subscription] Current offering: \(current.identifier)")
                print("[Subscription] Available packages (\(current.availablePackages.count)):")
                for pkg in current.availablePackages {
                    print("[Subscription]   - id: \(pkg.identifier), product: \(pkg.storeProduct.productIdentifier), price: \(pkg.storeProduct.localizedPriceString), currencyCode: \(pkg.storeProduct.currencyCode ?? "nil")")
                }

                if let monthly = current.monthly {
                    monthlyPriceDisplay = monthly.storeProduct.localizedPriceString
                    print("[Subscription] Monthly price loaded: \(monthly.storeProduct.localizedPriceString)")
                } else {
                    print("[Subscription] WARNING: monthly package not found in current offering")
                }

                if let yearly = current.annual {
                    yearlyPriceDisplay = yearly.storeProduct.localizedPriceString
                    print("[Subscription] Yearly price loaded: \(yearly.storeProduct.localizedPriceString)")
                } else {
                    print("[Subscription] WARNING: annual package not found in current offering")
                }
            } else {
                print("[Subscription] WARNING: No current offering found")
                print("[Subscription] All offering identifiers: \(offerings.all.keys.sorted())")
                for (id, offering) in offerings.all {
                    print("[Subscription]   Offering '\(id)': \(offering.availablePackages.count) packages")
                }
            }
        } catch {
            print("[Subscription] ERROR loading offerings: \(error)")
            print("[Subscription] Error details: \(error.localizedDescription)")
        }
    }

    func _refreshCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Premium status: \(isPremium)")
            print("[Subscription] Active entitlements: \(customerInfo.entitlements.active.keys.sorted())")
            print("[Subscription] App user ID: \(customerInfo.originalAppUserId)")
        } catch {
            print("[Subscription] Error checking status: \(error)")
            print("[Subscription] Error details: \(error.localizedDescription)")
        }
    }

    func _restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Restore completed. Premium: \(isPremium)")
        } catch {
            print("[Subscription] Restore error: \(error)")
            print("[Subscription] Restore error details: \(error.localizedDescription)")
        }
    }

    func _purchasePackage(packageType: PackageType) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            print("[Subscription] Fetching offerings for purchase '\(packageType)'...")
            let offerings = try await Purchases.shared.offerings()

            guard let current = offerings.current else {
                print("[Subscription] ERROR: No current offering available for purchase")
                return false
            }
            print("[Subscription] Current offering '\(current.identifier)' has \(current.availablePackages.count) packages")

            let package: Package?
            switch packageType {
            case .monthly: package = current.monthly
            case .annual: package = current.annual
            default: package = nil
            }

            guard let package else {
                print("[Subscription] ERROR: Package type '\(packageType)' not found in offering '\(current.identifier)'")
                print("[Subscription] Available package IDs: \(current.availablePackages.map(\.identifier))")
                return false
            }

            print("[Subscription] Purchasing package '\(package.identifier)': \(package.storeProduct.localizedPriceString) (\(package.storeProduct.productIdentifier))")
            let result = try await Purchases.shared.purchase(package: package)
            isPremium = result.customerInfo.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
            print("[Subscription] Purchase completed. Premium: \(isPremium)")
            return isPremium
        } catch {
            print("[Subscription] Purchase error: \(error)")
            print("[Subscription] Purchase error details: \(error.localizedDescription)")
            return false
        }
    }
}
#endif

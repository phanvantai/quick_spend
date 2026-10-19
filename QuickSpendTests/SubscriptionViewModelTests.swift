import Testing
import Foundation
@testable import QuickSpend

/// Mock subscription provider for isolated testing
struct MockSubscriptionProvider: SubscriptionProvider {
    var premiumStatus: Bool = false
    var prices: (monthly: String?, yearly: String?) = (nil, nil)
    var purchaseResult: Bool = false
    var restoreResult: Bool = false

    func configure() {}

    func checkPremiumStatus() async -> Bool {
        premiumStatus
    }

    func loadPrices() async -> (monthly: String?, yearly: String?) {
        prices
    }

    func purchase(monthly: Bool) async -> Bool {
        purchaseResult
    }

    func restorePurchases() async -> Bool {
        restoreResult
    }

    func syncPurchases() async -> Bool {
        premiumStatus
    }
}

/// Counts `syncPurchases()` calls so tests can check RevenueCat gets resynced.
final class SpySubscriptionProvider: SubscriptionProvider, @unchecked Sendable {
    var premiumStatus = false
    var purchaseResult = false
    var restoreResult = false
    private(set) var syncCallCount = 0

    func configure() {}
    func checkPremiumStatus() async -> Bool { premiumStatus }
    func loadPrices() async -> (monthly: String?, yearly: String?) { (nil, nil) }
    func purchase(monthly: Bool) async -> Bool { purchaseResult }
    func restorePurchases() async -> Bool { restoreResult }

    func syncPurchases() async -> Bool {
        syncCallCount += 1
        return premiumStatus
    }
}

/// Stands in for StoreKit's current entitlements.
struct MockStoreEntitlements: StoreEntitlementChecking {
    var hasActive = false

    func hasActiveSubscription() async -> Bool { hasActive }
}

@Suite("SubscriptionViewModel Tests")
@MainActor
struct SubscriptionViewModelTests {

    // MARK: - Test Helpers

    private func makeVM(
        premium: Bool = false,
        prices: (monthly: String?, yearly: String?) = (nil, nil),
        purchaseResult: Bool = false,
        restoreResult: Bool = false,
        storeKitActive: Bool = false
    ) -> SubscriptionViewModel {
        let mock = MockSubscriptionProvider(
            premiumStatus: premium,
            prices: prices,
            purchaseResult: purchaseResult,
            restoreResult: restoreResult
        )
        return SubscriptionViewModel(
            provider: mock,
            storeEntitlements: MockStoreEntitlements(hasActive: storeKitActive)
        )
    }

    // MARK: - Initial State

    @Test("Initial state is not premium")
    func testInitialNotPremium() {
        let vm = makeVM()
        #expect(vm.isPremium == false)
    }

    @Test("Initial state is not loading")
    func testInitialNotLoading() {
        let vm = makeVM()
        #expect(vm.isLoading == false)
    }

    @Test("Initial price displays are nil")
    func testInitialPriceDisplays() {
        let vm = makeVM()
        #expect(vm.monthlyPriceDisplay == nil)
        #expect(vm.yearlyPriceDisplay == nil)
    }

    // MARK: - Feature Gating (Free Tier)

    @Test("Free tier Gemini limit matches constants")
    func testFreeTierGeminiLimit() {
        let vm = makeVM()
        #expect(vm.geminiDailyLimit == AppConstants.freeTierGeminiLimit)
    }

    @Test("Free tier recurring templates limit matches constants")
    func testFreeTierRecurringLimit() {
        let vm = makeVM()
        #expect(vm.recurringTemplatesLimit == AppConstants.freeTierRecurringTemplatesLimit)
    }

    // MARK: - Feature Gating (Premium Tier)

    @Test("Premium Gemini limit is 999")
    func testPremiumGeminiLimit() {
        let vm = makeVM()
        vm._setPremium(true)
        #expect(vm.geminiDailyLimit == 999)
    }

    @Test("Premium recurring templates limit is 999")
    func testPremiumRecurringLimit() {
        let vm = makeVM()
        vm._setPremium(true)
        #expect(vm.recurringTemplatesLimit == 999)
    }

    // MARK: - canAddRecurringTemplate

    @Test("Free user can add if under limit")
    func testCanAddRecurringUnderLimit() {
        let vm = makeVM()
        #expect(vm.canAddRecurringTemplate(currentCount: 0) == true)
        #expect(vm.canAddRecurringTemplate(currentCount: 1) == true)
        #expect(vm.canAddRecurringTemplate(currentCount: 2) == true)
    }

    @Test("Free user cannot add at limit")
    func testCannotAddRecurringAtLimit() {
        let vm = makeVM()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit) == false)
    }

    @Test("Free user cannot add over limit")
    func testCannotAddRecurringOverLimit() {
        let vm = makeVM()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit + 1) == false)
    }

    @Test("Premium user can always add recurring templates")
    func testPremiumCanAlwaysAddRecurring() {
        let vm = makeVM()
        vm._setPremium(true)
        #expect(vm.canAddRecurringTemplate(currentCount: 100) == true)
        #expect(vm.canAddRecurringTemplate(currentCount: 999) == true)
    }

    // MARK: - Mock Provider Behavior

    @Test("initialize does not crash with mock provider")
    func testInitializeWithMock() {
        let vm = makeVM()
        vm.initialize()
        #expect(vm.isPremium == false)
    }

    @Test("loadOfferings populates prices from mock provider")
    func testLoadOfferingsWithMock() async {
        let vm = makeVM(prices: ("$4.99", "$39.99"))
        await vm.loadOfferings()
        #expect(vm.monthlyPriceDisplay == "$4.99")
        #expect(vm.yearlyPriceDisplay == "$39.99")
    }

    @Test("loadOfferings with nil prices keeps nil")
    func testLoadOfferingsNilPrices() async {
        let vm = makeVM()
        await vm.loadOfferings()
        #expect(vm.monthlyPriceDisplay == nil)
        #expect(vm.yearlyPriceDisplay == nil)
    }

    @Test("restorePurchases sets premium from mock result")
    func testRestorePurchasesWithMock() async {
        let vm = makeVM(restoreResult: false)
        await vm.restorePurchases()
        #expect(vm.isPremium == false)
        #expect(vm.isLoading == false)
    }

    @Test("purchaseMonthly returns false with mock")
    func testPurchaseMonthlyReturnsFalse() async {
        let vm = makeVM(purchaseResult: false)
        let result = await vm.purchaseMonthly()
        #expect(result == false)
        #expect(vm.isPremium == false)
        #expect(vm.isLoading == false)
    }

    @Test("purchaseMonthly returns true and sets premium with mock")
    func testPurchaseMonthlyReturnsTrue() async {
        let vm = makeVM(purchaseResult: true)
        let result = await vm.purchaseMonthly()
        #expect(result == true)
        #expect(vm.isPremium == true)
        #expect(vm.isLoading == false)
    }

    @Test("purchaseYearly returns false with mock")
    func testPurchaseYearlyReturnsFalse() async {
        let vm = makeVM(purchaseResult: false)
        let result = await vm.purchaseYearly()
        #expect(result == false)
        #expect(vm.isPremium == false)
        #expect(vm.isLoading == false)
    }

    @Test("purchaseYearly returns true and sets premium with mock")
    func testPurchaseYearlyReturnsTrue() async {
        let vm = makeVM(purchaseResult: true)
        let result = await vm.purchaseYearly()
        #expect(result == true)
        #expect(vm.isPremium == true)
        #expect(vm.isLoading == false)
    }

    @Test("refreshStatus updates premium from mock provider")
    func testRefreshStatusWithMock() async {
        let vm = makeVM(premium: false)
        await vm.refreshStatus()
        #expect(vm.isPremium == false)
    }

    // MARK: - StoreKit Fallback (regression: Premium lost on relaunch)

    @Test("refreshStatus is premium when RevenueCat says no but StoreKit has an active subscription")
    func testRefreshStatusFallsBackToStoreKit() async {
        let vm = makeVM(premium: false, storeKitActive: true)
        await vm.refreshStatus()
        #expect(vm.isPremium == true)
    }

    @Test("refreshStatus resyncs RevenueCat when only StoreKit sees the subscription")
    func testRefreshStatusResyncsRevenueCat() async {
        let spy = SpySubscriptionProvider()
        let vm = SubscriptionViewModel(provider: spy, storeEntitlements: MockStoreEntitlements(hasActive: true))
        await vm.refreshStatus()
        #expect(spy.syncCallCount == 1)
    }

    @Test("refreshStatus does not resync when RevenueCat already reports premium")
    func testRefreshStatusNoResyncWhenPremium() async {
        let spy = SpySubscriptionProvider()
        spy.premiumStatus = true
        let vm = SubscriptionViewModel(provider: spy, storeEntitlements: MockStoreEntitlements(hasActive: true))
        await vm.refreshStatus()
        #expect(vm.isPremium == true)
        #expect(spy.syncCallCount == 0)
    }

    @Test("refreshStatus stays free when neither RevenueCat nor StoreKit has a subscription")
    func testRefreshStatusFreeWhenNothingActive() async {
        let spy = SpySubscriptionProvider()
        let vm = SubscriptionViewModel(provider: spy, storeEntitlements: MockStoreEntitlements(hasActive: false))
        await vm.refreshStatus()
        #expect(vm.isPremium == false)
        #expect(spy.syncCallCount == 0)
    }

    @Test("purchase succeeds when the App Store says the user is already subscribed")
    func testPurchaseAlreadySubscribed() async {
        let vm = makeVM(purchaseResult: false, storeKitActive: true)
        let result = await vm.purchaseYearly()
        #expect(result == true)
        #expect(vm.isPremium == true)
        #expect(vm.isLoading == false)
    }

    @Test("restorePurchases is premium when StoreKit has an active subscription")
    func testRestoreFallsBackToStoreKit() async {
        let vm = makeVM(restoreResult: false, storeKitActive: true)
        await vm.restorePurchases()
        #expect(vm.isPremium == true)
    }

    // MARK: - Boundary Tests

    @Test("canAddRecurringTemplate at exactly limit-1 allows")
    func testCanAddRecurringBoundary() {
        let vm = makeVM()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit - 1) == true)
    }

    @Test("Feature limits are non-negative")
    func testFeatureLimitsNonNegative() {
        let vm = makeVM()
        #expect(vm.geminiDailyLimit > 0)
        #expect(vm.recurringTemplatesLimit > 0)
    }
}

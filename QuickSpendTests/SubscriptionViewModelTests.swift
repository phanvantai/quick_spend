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
}

@Suite("SubscriptionViewModel Tests")
@MainActor
struct SubscriptionViewModelTests {

    // MARK: - Test Helpers

    private func makeVM(
        premium: Bool = false,
        prices: (monthly: String?, yearly: String?) = (nil, nil),
        purchaseResult: Bool = false,
        restoreResult: Bool = false
    ) -> SubscriptionViewModel {
        let mock = MockSubscriptionProvider(
            premiumStatus: premium,
            prices: prices,
            purchaseResult: purchaseResult,
            restoreResult: restoreResult
        )
        return SubscriptionViewModel(provider: mock)
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

    @Test("Free tier report days limit matches constants")
    func testFreeTierReportDaysLimit() {
        let vm = makeVM()
        #expect(vm.reportDaysLimit == AppConstants.freeTierReportDaysLimit)
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

    @Test("Premium report days limit is 3650")
    func testPremiumReportDaysLimit() {
        let vm = makeVM()
        vm._setPremium(true)
        #expect(vm.reportDaysLimit == 365 * 10)
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
        #expect(vm.reportDaysLimit > 0)
    }
}

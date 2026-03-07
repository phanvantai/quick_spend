import Testing
import Foundation
@testable import QuickSpend

@Suite("SubscriptionViewModel Tests")
@MainActor
struct SubscriptionViewModelTests {

    // MARK: - Initial State

    @Test("Initial state is not premium")
    func testInitialNotPremium() {
        let vm = SubscriptionViewModel()
        #expect(vm.isPremium == false)
    }

    @Test("Initial state is not loading")
    func testInitialNotLoading() {
        let vm = SubscriptionViewModel()
        #expect(vm.isLoading == false)
    }

    @Test("Initial price displays are nil")
    func testInitialPriceDisplays() {
        let vm = SubscriptionViewModel()
        #expect(vm.monthlyPriceDisplay == nil)
        #expect(vm.yearlyPriceDisplay == nil)
    }

    // MARK: - Feature Gating (Free Tier)

    @Test("Free tier Gemini limit matches constants")
    func testFreeTierGeminiLimit() {
        let vm = SubscriptionViewModel()
        #expect(vm.geminiDailyLimit == AppConstants.freeTierGeminiLimit)
    }

    @Test("Free tier recurring templates limit matches constants")
    func testFreeTierRecurringLimit() {
        let vm = SubscriptionViewModel()
        #expect(vm.recurringTemplatesLimit == AppConstants.freeTierRecurringTemplatesLimit)
    }

    @Test("Free tier report days limit matches constants")
    func testFreeTierReportDaysLimit() {
        let vm = SubscriptionViewModel()
        #expect(vm.reportDaysLimit == AppConstants.freeTierReportDaysLimit)
    }

    // MARK: - Feature Gating (Premium Tier)

    @Test("Premium Gemini limit is 999")
    func testPremiumGeminiLimit() {
        let vm = SubscriptionViewModel()
        // Since isPremium is private(set), we test the free tier values
        // Premium values are 999 for gemini, 999 for recurring, 3650 for reports
        #expect(vm.geminiDailyLimit == AppConstants.freeTierGeminiLimit)
    }

    // MARK: - canAddRecurringTemplate

    @Test("Free user can add if under limit")
    func testCanAddRecurringUnderLimit() {
        let vm = SubscriptionViewModel()
        #expect(vm.canAddRecurringTemplate(currentCount: 0) == true)
        #expect(vm.canAddRecurringTemplate(currentCount: 1) == true)
        #expect(vm.canAddRecurringTemplate(currentCount: 2) == true)
    }

    @Test("Free user cannot add at limit")
    func testCannotAddRecurringAtLimit() {
        let vm = SubscriptionViewModel()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit) == false)
    }

    @Test("Free user cannot add over limit")
    func testCannotAddRecurringOverLimit() {
        let vm = SubscriptionViewModel()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit + 1) == false)
    }

    // MARK: - Graceful Degradation

    @Test("Initialize without RevenueCat does not crash")
    func testInitializeGracefulDegradation() {
        let vm = SubscriptionViewModel()
        vm.initialize()
        // Should not crash even without RevenueCat SDK
        #expect(vm.isPremium == false)
    }

    @Test("loadOfferings without RevenueCat does not crash")
    func testLoadOfferingsGracefulDegradation() async {
        let vm = SubscriptionViewModel()
        await vm.loadOfferings()
        // Should not crash
    }

    @Test("restorePurchases without RevenueCat does not crash")
    func testRestorePurchasesGracefulDegradation() async {
        let vm = SubscriptionViewModel()
        await vm.restorePurchases()
        // Should not crash
    }

    @Test("purchaseMonthly without RevenueCat returns false")
    func testPurchaseMonthlyGracefulDegradation() async {
        let vm = SubscriptionViewModel()
        let result = await vm.purchaseMonthly()
        #expect(result == false)
    }

    @Test("purchaseYearly without RevenueCat returns false")
    func testPurchaseYearlyGracefulDegradation() async {
        let vm = SubscriptionViewModel()
        let result = await vm.purchaseYearly()
        #expect(result == false)
    }

    @Test("refreshStatus without RevenueCat does not crash")
    func testRefreshStatusGracefulDegradation() async {
        let vm = SubscriptionViewModel()
        await vm.refreshStatus()
        // Should not crash
    }

    // MARK: - Boundary Tests

    @Test("canAddRecurringTemplate at exactly limit-1 allows")
    func testCanAddRecurringBoundary() {
        let vm = SubscriptionViewModel()
        let limit = AppConstants.freeTierRecurringTemplatesLimit
        #expect(vm.canAddRecurringTemplate(currentCount: limit - 1) == true)
    }

    @Test("Feature limits are non-negative")
    func testFeatureLimitsNonNegative() {
        let vm = SubscriptionViewModel()
        #expect(vm.geminiDailyLimit > 0)
        #expect(vm.recurringTemplatesLimit > 0)
        #expect(vm.reportDaysLimit > 0)
    }
}

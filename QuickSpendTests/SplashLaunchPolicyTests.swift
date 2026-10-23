import Testing
import SwiftUI
@testable import QuickSpend

@Suite("SplashLaunchPolicy Tests")
struct SplashLaunchPolicyTests {

    @Test("Recurring items are generated when the app returns to the foreground")
    func recurringGeneratedOnForeground() {
        #expect(SplashLaunchPolicy.shouldGenerateRecurring(on: .active, isLaunchComplete: true, isOnboardingComplete: true))
    }

    @Test("Recurring items are not generated in the background, during launch, or before onboarding")
    func recurringNotGeneratedOtherwise() {
        #expect(!SplashLaunchPolicy.shouldGenerateRecurring(on: .inactive, isLaunchComplete: true, isOnboardingComplete: true))
        #expect(!SplashLaunchPolicy.shouldGenerateRecurring(on: .background, isLaunchComplete: true, isOnboardingComplete: true))
        // Launch work generates them itself; don't race it.
        #expect(!SplashLaunchPolicy.shouldGenerateRecurring(on: .active, isLaunchComplete: false, isOnboardingComplete: true))
        #expect(!SplashLaunchPolicy.shouldGenerateRecurring(on: .active, isLaunchComplete: true, isOnboardingComplete: false))
    }
}

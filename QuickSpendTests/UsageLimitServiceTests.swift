import Testing
import Foundation
@testable import QuickSpend

@Suite("UsageLimitService Tests")
struct UsageLimitServiceTests {

    /// Create an isolated service with its own UserDefaults suite
    private func makeService() -> UsageLimitService {
        let suiteName = "test.usagelimit.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let service = UsageLimitService(defaults: defaults)
        return service
    }

    // MARK: - Initial State

    @Test("Initial usage count is 0")
    func testInitialUsageCount() {
        let service = makeService()
        #expect(service.usageCount == 0)
    }

    @Test("Initial state allows parsing")
    func testInitialCanParse() {
        let service = makeService()
        #expect(service.canParse == true)
        #expect(service.hasReachedLimit == false)
    }

    // MARK: - Increment

    @Test("incrementUsage increases count by 1")
    func testIncrementUsage() {
        let service = makeService()

        service.incrementUsage()
        #expect(service.usageCount == 1)

        service.incrementUsage()
        #expect(service.usageCount == 2)
    }

    @Test("Remaining count decreases with usage")
    func testRemainingCount() {
        let service = makeService()

        let initialRemaining = service.remainingCount
        service.incrementUsage()
        #expect(service.remainingCount == initialRemaining - 1)
    }

    // MARK: - Limits

    @Test("Free tier daily limit matches AppConstants")
    func testFreeTierLimit() {
        let service = makeService()
        service.isPremium = false
        #expect(service.dailyLimit == AppConstants.freeTierGeminiLimit)
    }

    @Test("Premium daily limit is 999")
    func testPremiumLimit() {
        let service = makeService()
        service.isPremium = true
        #expect(service.dailyLimit == 999)
    }

    @Test("hasReachedLimit is true when at limit")
    func testHasReachedLimit() {
        let service = makeService()
        service.isPremium = false

        for _ in 0..<AppConstants.freeTierGeminiLimit {
            service.incrementUsage()
        }

        #expect(service.hasReachedLimit == true)
        #expect(service.canParse == false)
    }

    @Test("Premium user never reaches limit")
    func testPremiumNeverReachesLimit() {
        let service = makeService()
        service.isPremium = true

        for _ in 0..<20 {
            service.incrementUsage()
        }

        #expect(service.hasReachedLimit == false)
        #expect(service.canParse == true)
        #expect(service.remainingCount == 999)
    }

    // MARK: - Reset

    @Test("resetCounter resets to 0")
    func testResetCounter() {
        let service = makeService()

        service.incrementUsage()
        service.incrementUsage()
        #expect(service.usageCount > 0)

        service.resetCounter()
        #expect(service.usageCount == 0)
    }

    @Test("After reset, canParse is true again")
    func testCanParseAfterReset() {
        let service = makeService()
        service.isPremium = false

        for _ in 0..<AppConstants.freeTierGeminiLimit {
            service.incrementUsage()
        }
        #expect(service.canParse == false)

        service.resetCounter()
        #expect(service.canParse == true)
    }

    // MARK: - Premium Toggle

    @Test("Toggling premium affects limits")
    func testPremiumToggle() {
        let service = makeService()

        service.isPremium = false
        #expect(service.dailyLimit == AppConstants.freeTierGeminiLimit)

        service.isPremium = true
        #expect(service.dailyLimit == 999)

        service.isPremium = false
        #expect(service.dailyLimit == AppConstants.freeTierGeminiLimit)
    }

    @Test("Remaining count is correct at boundary")
    func testRemainingCountBoundary() {
        let service = makeService()
        service.isPremium = false

        let limit = AppConstants.freeTierGeminiLimit
        #expect(service.remainingCount == limit)

        for i in 1...limit {
            service.incrementUsage()
            #expect(service.remainingCount == max(limit - i, 0))
        }

        // After reaching limit, remaining is 0
        #expect(service.remainingCount == 0)

        // Incrementing past limit still stays at 0 remaining
        service.incrementUsage()
        #expect(service.remainingCount == 0)
    }
}

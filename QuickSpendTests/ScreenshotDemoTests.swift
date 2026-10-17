import Foundation
import SwiftData
import Testing
@testable import QuickSpend

@Suite("ScreenshotDemo Tests")
@MainActor
struct ScreenshotDemoTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Oct 17, 2026, mid-month.
    private let now = Date(timeIntervalSince1970: 1_792_238_400)

    /// Returns the container, not just its context: a context whose container
    /// has been released crashes on fetch.
    private func seeded(now: Date? = nil) throws -> ModelContainer {
        let container = try ScreenshotDemo.makeContainer()
        try ScreenshotDemo.seed(into: container.mainContext, language: "en", now: now ?? self.now, calendar: calendar)
        return container
    }

    @Test("Seeds categories, wallets, balances, recurring templates, and transactions")
    func testSeedsEverything() throws {
        let container = try seeded()
        let context = container.mainContext

        #expect(try context.fetchCount(FetchDescriptor<QuickSpend.Category>()) == CategoryService.defaultCategories(language: "en").count)
        let walletIds = Set(try context.fetch(FetchDescriptor<Wallet>()).map(\.id))
        #expect(walletIds == [Wallet.personalID, ScreenshotDemo.bankWalletId, ScreenshotDemo.savingsWalletId])
        #expect(try context.fetchCount(FetchDescriptor<BalanceAnchor>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<RecurringTemplate>()) >= 3)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) >= 30)
    }

    @Test("Every transaction uses a known category and wallet")
    func testReferencesAreValid() throws {
        let container = try seeded()
        let context = container.mainContext
        let categoryIds = Set(try context.fetch(FetchDescriptor<QuickSpend.Category>()).map(\.id))
        let walletIds = Set(try context.fetch(FetchDescriptor<Wallet>()).map(\.id))

        for transaction in try context.fetch(FetchDescriptor<Transaction>()) {
            #expect(transaction.isTransfer || categoryIds.contains(transaction.categoryId), "\(transaction.categoryId)")
            #expect(walletIds.contains(transaction.walletId))
        }
        for template in try context.fetch(FetchDescriptor<RecurringTemplate>()) {
            #expect(categoryIds.contains(template.categoryId))
            #expect(walletIds.contains(template.walletId))
        }
    }

    @Test("The current and previous months both have income and expenses, and nothing is in the future")
    func testDatesFillTwoMonths() throws {
        let container = try seeded()
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>()).filter { !$0.isTransfer }
        let thisMonth = calendar.dateInterval(of: .month, for: now)!
        let lastMonth = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: -1, to: now)!)!

        for interval in [thisMonth, lastMonth] {
            let inMonth = transactions.filter { interval.contains($0.date) }
            #expect(inMonth.contains { $0.type == .income })
            #expect(inMonth.contains { $0.type == .expense })
        }
        #expect(transactions.allSatisfy { $0.date <= now })
    }

    @Test("Each of the last 6 months has income and expenses for the trend chart")
    func testSixMonthTrend() throws {
        let container = try seeded()
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>()).filter { !$0.isTransfer }
        for monthsBack in 0..<6 {
            let month = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: -monthsBack, to: now)!)!
            let inMonth = transactions.filter { month.contains($0.date) }
            #expect(inMonth.contains { $0.type == .income }, "\(monthsBack) months back")
            #expect(inMonth.contains { $0.type == .expense }, "\(monthsBack) months back")
        }
    }

    @Test("Early in a month nothing is dated after today")
    func testFirstDayOfMonth() throws {
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 9))!
        let container = try seeded(now: firstDay)
        let transactions = try container.mainContext.fetch(FetchDescriptor<Transaction>())
        #expect(transactions.allSatisfy { $0.date <= firstDay })
    }

    @Test("Includes a transfer saved as two legs")
    func testTransfer() throws {
        let container = try seeded()
        let legs = try container.mainContext.fetch(FetchDescriptor<Transaction>()).filter(\.isTransfer)
        #expect(legs.count == 2)
        #expect(Set(legs.compactMap(\.transferLeg)) == [.outgoing, .incoming])
    }

    @Test("Demo voice text is used only in demo mode and when not blank")
    func testVoiceText() {
        let suite = "screenshot-demo-voice-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let demo = ["QuickSpend", ScreenshotDemo.launchArgument]

        #expect(ScreenshotDemo.voiceText(defaults: defaults, arguments: demo) == nil)
        defaults.set("  coffee 5 dollars test ", forKey: ScreenshotDemo.voiceTextKey)
        #expect(ScreenshotDemo.voiceText(defaults: defaults, arguments: demo) == "coffee 5 dollars test")
        #expect(ScreenshotDemo.voiceText(defaults: defaults, arguments: ["QuickSpend"]) == nil)
        defaults.set("   ", forKey: ScreenshotDemo.voiceTextKey)
        #expect(ScreenshotDemo.voiceText(defaults: defaults, arguments: demo) == nil)
    }

    @Test("Preferences skip onboarding and promos, and never share voice samples")
    func testPreparePreferences() {
        let suite = "screenshot-demo-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesService(defaults: defaults)

        ScreenshotDemo.preparePreferences(preferences, language: "vi")

        let config = preferences.getConfig()
        #expect(config.isOnboardingComplete)
        #expect(config.hasSeenVoiceShortcutPromo)
        #expect(config.language == "vi")
        #expect(config.currency == "USD")
        #expect(preferences.hasShownVoiceTutorial)
        #expect(!preferences.shouldShowWalletsWhatsNew)
        #expect(!preferences.shareVoiceSamples)
        #expect(preferences.selectedWalletScopeRawValue == WalletScope.all.rawValue)
    }
}

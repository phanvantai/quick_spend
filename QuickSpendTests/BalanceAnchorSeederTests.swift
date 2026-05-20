import Testing
import Foundation
import SwiftData
@testable import QuickSpend

@Suite("BalanceAnchorSeeder Tests")
@MainActor
struct BalanceAnchorSeederTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
            configurations: config
        )
    }

    @Test("Seeds a zero-balance anchor when none exists — onboarding flow path")
    func testSeedsAnchorWhenEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inserted = BalanceAnchorSeeder.seedIfNeeded(modelContext: context)
        #expect(inserted == true)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.openingBalance == 0)
    }

    @Test("Anchor date is set to start-of-day for the provided `now`")
    func testAnchorDateIsStartOfDay() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let now = Date(timeIntervalSince1970: 1_700_000_000) // arbitrary mid-day moment
        BalanceAnchorSeeder.seedIfNeeded(modelContext: context, now: now)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        let expected = Calendar.current.startOfDay(for: now)
        #expect(anchors.first?.anchorDate == expected)
    }

    @Test("Idempotent — second call is a no-op when an anchor already exists")
    func testIdempotentNoSecondInsert() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let firstInserted = BalanceAnchorSeeder.seedIfNeeded(modelContext: context)
        #expect(firstInserted == true)

        let secondInserted = BalanceAnchorSeeder.seedIfNeeded(modelContext: context)
        #expect(secondInserted == false)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(anchors.count == 1)
    }

    @Test("Does not overwrite an existing non-zero opening balance — respects user input")
    func testDoesNotOverwriteExistingAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // User had already set up balance manually via Settings
        let existing = BalanceAnchor(openingBalance: 5_000_000, anchorDate: Date())
        context.insert(existing)
        try context.save()

        let inserted = BalanceAnchorSeeder.seedIfNeeded(modelContext: context)
        #expect(inserted == false)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.openingBalance == 5_000_000)
    }
}

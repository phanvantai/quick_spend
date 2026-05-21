import Testing
import Foundation
@testable import QuickSpend

@Suite("BalanceCacheStore Tests")
struct BalanceCacheStoreTests {

    /// Create a fresh, isolated UserDefaults suite for each test. The suite is wiped
    /// on entry so no state leaks between runs.
    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "BalanceCacheStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func cleanup(_ defaults: UserDefaults, _ suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Empty store — cachedBalance and lastComputedAt are nil before any write")
    func testEmptyStateNil() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { cleanup(defaults, suite) }

        let store = BalanceCacheStore(defaults: defaults)
        #expect(store.cachedBalance == nil)
        #expect(store.lastComputedAt == nil)
    }

    @Test("Write + read roundtrip — both balance and timestamp persist")
    func testWriteReadRoundtrip() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { cleanup(defaults, suite) }

        let store = BalanceCacheStore(defaults: defaults)
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        store.write(balance: 1_234_567, at: timestamp)

        #expect(store.cachedBalance == 1_234_567)
        #expect(store.lastComputedAt == timestamp)
    }

    @Test("Negative balance persists correctly (overdrawn account)")
    func testNegativeBalancePersists() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { cleanup(defaults, suite) }

        let store = BalanceCacheStore(defaults: defaults)
        store.write(balance: -50_000, at: Date())

        #expect(store.cachedBalance == -50_000)
    }

    @Test("Zero balance is distinguishable from no-write — reads back as 0, not nil")
    func testZeroBalanceVsNil() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { cleanup(defaults, suite) }

        let store = BalanceCacheStore(defaults: defaults)
        store.write(balance: 0, at: Date())

        #expect(store.cachedBalance == 0)
        #expect(store.cachedBalance != nil)
    }

    @Test("Clear — removes both balance and timestamp")
    func testClearRemovesBoth() {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { cleanup(defaults, suite) }

        let store = BalanceCacheStore(defaults: defaults)
        store.write(balance: 100, at: Date())
        #expect(store.cachedBalance != nil)

        store.clear()

        #expect(store.cachedBalance == nil)
        #expect(store.lastComputedAt == nil)
    }

    @Test("Independent stores on different suites do NOT see each other's data")
    func testSuiteIsolation() {
        let (defaultsA, suiteA) = makeIsolatedDefaults()
        let (defaultsB, suiteB) = makeIsolatedDefaults()
        defer { cleanup(defaultsA, suiteA); cleanup(defaultsB, suiteB) }

        let storeA = BalanceCacheStore(defaults: defaultsA)
        let storeB = BalanceCacheStore(defaults: defaultsB)

        storeA.write(balance: 111, at: Date())

        #expect(storeA.cachedBalance == 111)
        #expect(storeB.cachedBalance == nil)
    }
}

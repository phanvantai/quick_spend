import Testing
import Foundation
import SwiftData
import Combine
@testable import QuickSpend

@Suite("BalanceService Tests")
@MainActor
struct BalanceServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
            configurations: config
        )
    }

    private func insertAnchor(
        openingBalance: Double,
        anchorDate: Date,
        walletId: String = Wallet.personalID,
        in context: ModelContext
    ) throws {
        let anchor = BalanceAnchor(walletId: walletId, openingBalance: openingBalance, anchorDate: anchorDate)
        context.insert(anchor)
        try context.save()
    }

    /// Isolated UserDefaults suite + BalanceCacheStore for cache-integration tests.
    private func makeIsolatedCacheStore() -> (BalanceCacheStore, UserDefaults, String) {
        let suite = "BalanceServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (BalanceCacheStore(defaults: defaults), defaults, suite)
    }

    // MARK: - Test 1: Empty state

    @Test("Empty state — balance equals openingBalance when no transactions exist")
    func testEmptyStateBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 1_000_000)
    }

    // MARK: - Test 2: Income adds to balance

    @Test("Income transaction — balance = opening + income amount")
    func testIncomeAddsToBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 500_000, anchorDate: anchorDate, in: context)

        let income = Transaction(
            amount: 200_000,
            note: "Salary",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(3600) // 1 hour after anchor
        )
        context.insert(income)
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 700_000)
    }

    @Test("Wallet balance includes only matching wallet transactions")
    func testWalletBalanceFiltersTransactionsByWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Calendar.current.startOfDay(for: Date())

        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, walletId: Wallet.personalID, in: context)
        try insertAnchor(openingBalance: 500, anchorDate: anchorDate, walletId: "wallet_side_work", in: context)

        context.insert(Transaction(amount: 200, note: "Personal income", categoryId: "salary", walletId: Wallet.personalID, type: .income, createdAt: anchorDate.addingTimeInterval(10)))
        context.insert(Transaction(amount: 75, note: "Personal expense", categoryId: "food", walletId: Wallet.personalID, type: .expense, createdAt: anchorDate.addingTimeInterval(20)))
        context.insert(Transaction(amount: 400, note: "Side income", categoryId: "salary", walletId: "wallet_side_work", type: .income, createdAt: anchorDate.addingTimeInterval(30)))
        context.insert(Transaction(amount: 50, note: "Side expense", categoryId: "tools", walletId: "wallet_side_work", type: .expense, createdAt: anchorDate.addingTimeInterval(40)))
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        #expect(try service.computeBalance(walletId: Wallet.personalID) == 1_125)
        #expect(try service.computeBalance(walletId: "wallet_side_work") == 850)
        #expect(try service.computeTotalBalance(walletIds: [Wallet.personalID, "wallet_side_work"]) == 1_975)
    }

    @Test("Setting a wallet balance creates its wallet-scoped anchor")
    func testSetCurrentBalanceCreatesWalletAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let confirmationDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        try service.setCurrentBalance(2_500, for: "wallet_side_work", at: confirmationDate)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.id == BalanceAnchor.id(for: "wallet_side_work"))
        #expect(anchors.first?.walletId == "wallet_side_work")
        #expect(anchors.first?.openingBalance == 2_500)
        #expect(anchors.first?.anchorDate == confirmationDate)
        #expect(try service.computeBalance(walletId: "wallet_side_work") == 2_500)
    }

    @Test("Resetting a wallet balance moves its anchor so earlier transactions are not counted twice")
    func testSetCurrentBalanceUpdatesExistingAnchorDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let confirmationDate = originalDate.addingTimeInterval(120)
        try insertAnchor(
            openingBalance: 1_000,
            anchorDate: originalDate,
            walletId: "wallet_side_work",
            in: context
        )
        context.insert(Transaction(
            amount: 200,
            note: "Before reset",
            categoryId: "food",
            walletId: "wallet_side_work",
            type: .expense,
            createdAt: originalDate.addingTimeInterval(60)
        ))
        try context.save()
        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        try service.setCurrentBalance(3_000, for: "wallet_side_work", at: confirmationDate)

        let anchors = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(anchors.count == 1)
        #expect(anchors.first?.openingBalance == 3_000)
        #expect(anchors.first?.anchorDate == confirmationDate)
        #expect(try service.computeBalance(walletId: "wallet_side_work") == 3_000)
    }

    @Test("Setting Personal balance refreshes the observable balance immediately")
    func testSetCurrentBalanceRefreshesPersonalBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let confirmationDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        try service.setCurrentBalance(4_200, for: Wallet.personalID, at: confirmationDate)

        #expect(service.currentBalance == 4_200)
        #expect(try service.computeBalance() == 4_200)
    }

    // MARK: - Test 3: Expense subtracts from balance

    @Test("Expense transaction — balance = opening − expense amount")
    func testExpenseSubtractsFromBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 500_000, anchorDate: anchorDate, in: context)

        let expense = Transaction(
            amount: 75_000,
            note: "Lunch",
            categoryId: "food_drink",
            type: .expense,
            date: anchorDate.addingTimeInterval(3600)
        )
        context.insert(expense)
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 425_000)
    }

    // MARK: - Test 4: Multi-transaction sum (10 mixed)

    @Test("Multi-transaction — balance correctly sums 10 mixed income/expense entries")
    func testMultiTransactionSum() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        // 5 incomes totaling 500_000, 5 expenses totaling 300_000 → net +200_000
        let incomes: [Double] = [100_000, 100_000, 100_000, 100_000, 100_000]
        let expenses: [Double] = [50_000, 60_000, 70_000, 60_000, 60_000]

        for (i, amount) in incomes.enumerated() {
            let tx = Transaction(
                amount: amount,
                note: "Income \(i)",
                categoryId: "salary",
                type: .income,
                date: anchorDate.addingTimeInterval(Double(i + 1) * 3600)
            )
            context.insert(tx)
        }
        for (i, amount) in expenses.enumerated() {
            let tx = Transaction(
                amount: amount,
                note: "Expense \(i)",
                categoryId: "food_drink",
                type: .expense,
                date: anchorDate.addingTimeInterval(Double(i + 100) * 3600)
            )
            context.insert(tx)
        }
        try context.save()

        let service = BalanceService(modelContext: context)
        let balance = try service.computeBalance()

        #expect(balance == 1_200_000)
    }

    // MARK: - Test 5: Anchor date >= boundary inclusive

    @Test("Anchor boundary uses Transaction.createdAt (creation instant), not .date — so the user-picked date doesn't change whether a transaction is included in the running balance")
    func testAnchorDateBoundaryInclusive() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000_000, anchorDate: anchorDate, in: context)

        // Transaction logged BEFORE the anchor moment (createdAt < anchorDate).
        // `.date` is set in the future, but it's user-picked metadata — it
        // doesn't change inclusion. Must be excluded.
        let before = Transaction(
            amount: 999_999,
            note: "Logged before anchor",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(7200), // future user date
            createdAt: anchorDate.addingTimeInterval(-1) // logged 1s before anchor
        )
        context.insert(before)

        // Transaction logged EXACTLY at the anchor instant — included (>= boundary).
        let onBoundary = Transaction(
            amount: 100_000,
            note: "Logged at anchor",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(-86_400), // user-picked yesterday
            createdAt: anchorDate
        )
        context.insert(onBoundary)

        // Transaction logged AFTER anchor with a noon-of-today .date — included
        // even though `.date` precedes the anchor instant. This is the specific
        // case Codex flagged: TransactionFormView defaults selectedDate to
        // noon-today, so a 3pm balance edit + 4pm new expense would have
        // .date < anchor under the old predicate.
        let after = Transaction(
            amount: 50_000,
            note: "Logged after anchor, noon-today date",
            categoryId: "food_drink",
            type: .expense,
            date: anchorDate.addingTimeInterval(43_200), // noon-today (anchor < this)
            createdAt: anchorDate.addingTimeInterval(54_000) // 3pm-today (after anchor)
        )
        context.insert(after)

        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        let balance = try service.computeBalance()

        // 1_000_000 opening + 100_000 (on) − 50_000 (after) = 1_050_000
        // before (createdAt < anchor) excluded regardless of its user-picked date
        #expect(balance == 1_050_000)
    }

    // MARK: - Test 6: Defensive multi-row recovery

    @Test("Multi-row recovery — when >1 anchor exists, keep oldest createdAt and delete extras")
    func testMultiRowRecovery() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let baseDate = Calendar.current.startOfDay(for: Date())

        // Insert 3 anchors with distinct createdAt (oldest first)
        let oldest = BalanceAnchor(
            openingBalance: 100,
            anchorDate: baseDate,
            createdAt: baseDate.addingTimeInterval(-3600)
        )
        let middle = BalanceAnchor(
            id: "00000000-0000-0000-0000-000000000002", // distinct id to bypass unique constraint
            openingBalance: 200,
            anchorDate: baseDate,
            createdAt: baseDate.addingTimeInterval(-1800)
        )
        let newest = BalanceAnchor(
            id: "00000000-0000-0000-0000-000000000003",
            openingBalance: 300,
            anchorDate: baseDate,
            createdAt: baseDate
        )
        context.insert(oldest)
        context.insert(middle)
        context.insert(newest)
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        // recomputeNow() runs the duplicate-anchor recovery before computing.
        // computeBalance() is a pure read after the refactor — no side effects.
        try service.recomputeNow()

        // Oldest opening balance wins (100), and the other 2 should be deleted
        #expect(service.currentBalance == 100)

        let remaining = try context.fetch(FetchDescriptor<BalanceAnchor>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.openingBalance == 100)
    }

    // MARK: - Test 6b: BalanceAnchor inserts trigger recompute (regression)

    @Test("willSave hook — inserting a BalanceAnchor triggers a debounced recompute (so the Setup CTA flips to display state without an explicit refresh)")
    func testWillSaveBalanceAnchorInsertTriggersRecompute() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // No anchor yet — service starts in nil-balance state
        let service = BalanceService(modelContext: context)
        let initialCount = service.recomputeCount
        #expect(service.currentBalance == nil)

        // Mimic the WalletForm first-time balance path: insert + save
        let anchor = BalanceAnchor(
            openingBalance: 1_500_000,
            anchorDate: Date()
        )
        context.insert(anchor)
        try context.save()

        try await Task.sleep(for: .milliseconds(500))

        #expect(service.recomputeCount > initialCount)
        #expect(service.currentBalance == 1_500_000)
    }

    // MARK: - Test 6c: clearAll wipes cache + currentBalance (deleteAllData path)

    @Test("clearAll() — wipes cache + currentBalance so SettingsView's delete-all path matches the now-empty store")
    func testClearAllWipesState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (cache, defaults, suite) = makeIsolatedCacheStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 5_000, anchorDate: anchorDate, in: context)

        let service = BalanceService(
            modelContext: context,
            cacheStore: cache,
            autoObserve: false,
            autoCompute: true
        )

        #expect(service.currentBalance == 5_000)
        #expect(cache.cachedBalance == 5_000)

        service.clearAll()

        #expect(service.currentBalance == nil)
        #expect(cache.cachedBalance == nil)
    }

    // MARK: - Test 7: willSave hook triggers recompute on Transaction change

    @Test("willSave hook — inserting a Transaction triggers a debounced recompute")
    func testWillSaveTransactionTriggersRecompute() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context)
        // Initial autoCompute should have set currentBalance to 1_000
        #expect(service.currentBalance == 1_000)
        let initialCount = service.recomputeCount

        let tx = Transaction(
            amount: 250,
            note: "Coffee",
            categoryId: "food_drink",
            type: .expense,
            date: anchorDate.addingTimeInterval(60)
        )
        context.insert(tx)
        try context.save()

        // Wait long enough for the 200ms debounce to fire (+ generous slack for CI)
        try await Task.sleep(for: .milliseconds(500))

        #expect(service.currentBalance == 750)
        #expect(service.recomputeCount > initialCount)
    }

    // MARK: - Test 8: willSave hook does NOT trigger recompute on unrelated model change

    @Test("willSave hook — Category-only changes do NOT trigger recompute (unrelated to balance inputs)")
    func testWillSaveCategoryOnlyDoesNotTriggerRecompute() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 500, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context)
        let countAfterInit = service.recomputeCount

        let category = Category(
            id: "test_cat",
            name: "Test",
            iconName: "circle",
            colorHex: "#000000",
            type: .expense,
            group: .other,
            sortOrder: 99
        )
        context.insert(category)
        try context.save()

        try await Task.sleep(for: .milliseconds(500))

        #expect(service.recomputeCount == countAfterInit)
    }

    // MARK: - Test 9: Debounce coalesces a burst of schedule calls

    // MARK: - Test 10: Cache seed on init (cold start)

    @Test("Cache seed — service init reads cachedBalance from store before computing")
    func testInitSeedsCurrentBalanceFromCache() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (cache, defaults, suite) = makeIsolatedCacheStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Pre-seed cache with a known stale value
        cache.write(balance: 42, at: Date())

        // No anchor in store + autoCompute=false → currentBalance must come from cache only
        let service = BalanceService(
            modelContext: context,
            cacheStore: cache,
            autoObserve: false,
            autoCompute: false
        )

        #expect(service.currentBalance == 42)
    }

    // MARK: - Test 11: Cache write on successful recompute

    @Test("Cache write — recompute persists the new balance to the cache store")
    func testRecomputeWritesCache() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (cache, defaults, suite) = makeIsolatedCacheStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 999, anchorDate: anchorDate, in: context)

        let service = BalanceService(
            modelContext: context,
            cacheStore: cache,
            autoObserve: false,
            autoCompute: true
        )

        #expect(service.currentBalance == 999)
        #expect(cache.cachedBalance == 999)
        #expect(cache.lastComputedAt != nil)
    }

    // MARK: - Test 12: Cache cleared when anchor disappears

    @Test("Cache clear — when no anchor exists, recompute clears the cache")
    func testRecomputeWithoutAnchorClearsCache() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (cache, defaults, suite) = makeIsolatedCacheStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Pre-seed cache as if a previous session had a balance
        cache.write(balance: 5_000, at: Date())
        #expect(cache.cachedBalance == 5_000)

        // No anchor in store → recompute returns nil → cache must be cleared
        let service = BalanceService(
            modelContext: context,
            cacheStore: cache,
            autoObserve: false,
            autoCompute: true
        )

        #expect(service.currentBalance == nil)
        #expect(cache.cachedBalance == nil)
    }

    // MARK: - Test 13: CloudKit import event triggers recompute

    @Test("Import event — firing the importEventPublisher triggers a debounced recompute")
    func testImportEventTriggersRecompute() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (cache, defaults, suite) = makeIsolatedCacheStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let importSubject = PassthroughSubject<Void, Never>()

        // autoObserve=false isolates this to the import-event path only — no willSave
        // observer can confound the recompute count.
        let service = BalanceService(
            modelContext: context,
            cacheStore: cache,
            importEventPublisher: importSubject.eraseToAnyPublisher(),
            autoObserve: false,
            autoCompute: true
        )

        let initialCount = service.recomputeCount

        // Simulate CloudKit finishing an import after a remote device added a Transaction
        let newTx = Transaction(
            amount: 250,
            note: "Remote add",
            categoryId: "salary",
            type: .income,
            date: anchorDate.addingTimeInterval(120)
        )
        context.insert(newTx)
        try context.save()

        // willSave fires too, but autoObserve=false means the service ignores it.
        // Only the import event should drive the recompute.
        importSubject.send()

        try await Task.sleep(for: .milliseconds(500))

        #expect(service.recomputeCount == initialCount + 1)
        #expect(service.currentBalance == 1_250)
    }

    @Test("Import event — backfills remote legacy records missing walletId before recompute")
    func testImportEventBackfillsLegacyWalletIds() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let importSubject = PassthroughSubject<Void, Never>()
        let service = BalanceService(
            modelContext: context,
            importEventPublisher: importSubject.eraseToAnyPublisher(),
            autoObserve: false,
            autoCompute: false
        )
        _ = service

        let remoteLegacy = Transaction(amount: 25, note: "Remote legacy", categoryId: "food", type: .expense)
        remoteLegacy.walletId = ""
        context.insert(remoteLegacy)
        try context.save()

        importSubject.send()
        try await Task.sleep(for: .milliseconds(500))

        #expect(remoteLegacy.walletId == Wallet.personalID)
    }

    @Test("Debounce — 5 rapid scheduleRecompute() calls coalesce to a single recompute")
    func testDebounceCoalescesBurst() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Calendar.current.startOfDay(for: Date())
        try insertAnchor(openingBalance: 100, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context, autoObserve: false)
        let initialCount = service.recomputeCount

        for _ in 0..<5 {
            service.scheduleRecompute()
        }

        try await Task.sleep(for: .milliseconds(500))

        #expect(service.recomputeCount - initialCount == 1)
    }

    // MARK: - Optimistic updates

    @Test("Optimistic insert — income increases currentBalance immediately, before any recompute")
    func testOptimisticInsertIncome() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date().addingTimeInterval(-3600)
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 1_000)

        let tx = Transaction(amount: 250, note: "", categoryId: "x", type: .income, date: .now)
        context.insert(tx)
        let before = service.recomputeCount
        service.applyOptimisticInsert(tx)

        #expect(service.currentBalance == 1_250)
        #expect(service.recomputeCount == before) // optimistic update did NOT trigger recompute
    }

    @Test("Optimistic insert — expense decreases currentBalance immediately")
    func testOptimisticInsertExpense() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try insertAnchor(openingBalance: 1_000, anchorDate: Date().addingTimeInterval(-3600), in: context)

        let service = BalanceService(modelContext: context, autoObserve: false)
        let tx = Transaction(amount: 150, note: "", categoryId: "x", type: .expense, date: .now)
        context.insert(tx)
        service.applyOptimisticInsert(tx)

        #expect(service.currentBalance == 850)
    }

    @Test("Optimistic insert — no-op when no anchor exists")
    func testOptimisticInsertWithoutAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == nil)

        let tx = Transaction(amount: 500, note: "", categoryId: "x", type: .income, date: .now)
        context.insert(tx)
        service.applyOptimisticInsert(tx)

        #expect(service.currentBalance == nil)
    }

    @Test("Optimistic insert — no-op when tx.createdAt predates anchor (excluded from compute predicate)")
    func testOptimisticInsertPredatingAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date()
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)
        let service = BalanceService(modelContext: context, autoObserve: false)

        // Construct a tx with createdAt before the anchor.
        let tx = Transaction(amount: 500, note: "", categoryId: "x", type: .income, date: .now)
        tx.createdAt = anchorDate.addingTimeInterval(-60)
        context.insert(tx)
        service.applyOptimisticInsert(tx)

        #expect(service.currentBalance == 1_000)
    }

    @Test("Optimistic insert — result matches authoritative recompute")
    func testOptimisticInsertMatchesRecompute() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try insertAnchor(openingBalance: 1_000, anchorDate: Date().addingTimeInterval(-3600), in: context)
        let service = BalanceService(modelContext: context, autoObserve: false)

        let tx = Transaction(amount: 250, note: "", categoryId: "x", type: .income, date: .now)
        context.insert(tx)
        try context.save()
        service.applyOptimisticInsert(tx)
        let optimistic = service.currentBalance

        try service.recomputeNow()
        #expect(service.currentBalance == optimistic)
    }

    @Test("Computing another wallet balance does not change Personal optimistic insert anchor")
    func testOtherWalletComputeDoesNotPoisonPersonalOptimisticAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let personalAnchorDate = Date().addingTimeInterval(-3_600)
        let sideAnchorDate = Date().addingTimeInterval(3_600)
        try insertAnchor(openingBalance: 1_000, anchorDate: personalAnchorDate, walletId: Wallet.personalID, in: context)
        try insertAnchor(openingBalance: 500, anchorDate: sideAnchorDate, walletId: "wallet_side_work", in: context)

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 1_000)

        _ = try service.computeBalance(walletId: "wallet_side_work")

        let tx = Transaction(
            amount: 100,
            note: "Personal coffee",
            categoryId: "food",
            walletId: Wallet.personalID,
            type: .expense,
            date: .now,
            createdAt: Date()
        )
        context.insert(tx)
        service.applyOptimisticInsert(tx)

        #expect(service.currentBalance == 900)
    }

    @Test("Optimistic delete — subtracts the transaction's signed amount")
    func testOptimisticDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date().addingTimeInterval(-3600)
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let tx = Transaction(amount: 200, note: "", categoryId: "x", type: .expense, date: .now)
        context.insert(tx)
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 800)

        service.applyOptimisticDelete(tx)
        #expect(service.currentBalance == 1_000)
    }

    @Test("Optimistic edit — applies delta between old and new signed amounts")
    func testOptimisticEditAmountChange() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date().addingTimeInterval(-3600)
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let tx = Transaction(amount: 100, note: "", categoryId: "x", type: .expense, date: .now)
        context.insert(tx)
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 900)

        // User edits the amount from 100 → 250 (still expense).
        service.applyOptimisticEdit(
            createdAt: tx.createdAt,
            oldAmount: 100, oldType: .expense,
            newAmount: 250, newType: .expense
        )
        #expect(service.currentBalance == 750)
    }

    @Test("Optimistic edit — moving a Personal expense to another wallet restores Personal balance")
    func testOptimisticEditMovingExpenseOutOfPersonalWallet() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date().addingTimeInterval(-3600)
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let tx = Transaction(
            amount: 100,
            note: "",
            categoryId: "x",
            walletId: Wallet.personalID,
            type: .expense,
            date: .now
        )
        context.insert(tx)
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 900)

        service.applyOptimisticEdit(
            createdAt: tx.createdAt,
            oldAmount: 100,
            oldType: .expense,
            oldWalletId: Wallet.personalID,
            newAmount: 100,
            newType: .expense,
            newWalletId: "wallet_side_work"
        )

        #expect(service.currentBalance == 1_000)
    }

    @Test("Optimistic edit — type flip from expense to income inverts the contribution")
    func testOptimisticEditTypeFlip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let anchorDate = Date().addingTimeInterval(-3600)
        try insertAnchor(openingBalance: 1_000, anchorDate: anchorDate, in: context)

        let tx = Transaction(amount: 100, note: "", categoryId: "x", type: .expense, date: .now)
        context.insert(tx)
        try context.save()

        let service = BalanceService(modelContext: context, autoObserve: false)
        #expect(service.currentBalance == 900)

        // Flip 100 expense → 100 income: balance moves by +200.
        service.applyOptimisticEdit(
            createdAt: tx.createdAt,
            oldAmount: 100, oldType: .expense,
            newAmount: 100, newType: .income
        )
        #expect(service.currentBalance == 1_100)
    }
}

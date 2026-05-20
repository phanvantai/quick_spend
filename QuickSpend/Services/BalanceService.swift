import Foundation
import SwiftData
import Observation
import Combine

/// Computes and tracks the user's current account balance from `BalanceAnchor` + `Transaction`
/// history. Observes `ModelContext.willSave` and debounces recompute by 200ms to coalesce
/// CloudKit-import bursts and rapid CRUD sequences.
///
/// Defensive: if more than one `BalanceAnchor` row is found (e.g. CloudKit last-writer-wins
/// race despite the fixed singleton UUID), keeps the oldest `createdAt` and deletes the rest.
///
/// Formula: `balance = openingBalance + Σ(income.amount where date >= anchorDate) − Σ(expense.amount where date >= anchorDate)`
@MainActor
@Observable
final class BalanceService {
    /// Latest computed balance. `nil` means no anchor exists yet (user hasn't set up balance).
    private(set) var currentBalance: Double?

    /// Recompute counter — used by tests and useful for diagnostics.
    private(set) var recomputeCount: Int = 0

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let cacheStore: BalanceCacheStore
    @ObservationIgnored private var observerToken: NSObjectProtocol?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var importSubscription: AnyCancellable?

    /// 200ms — coalesces notification bursts (CloudKit import, rapid CRUD).
    static let debounceInterval: Duration = .milliseconds(200)

    init(
        modelContext: ModelContext,
        cacheStore: BalanceCacheStore = BalanceCacheStore(),
        importEventPublisher: AnyPublisher<Void, Never>? = nil,
        autoObserve: Bool = true,
        autoCompute: Bool = true
    ) {
        self.modelContext = modelContext
        self.cacheStore = cacheStore
        // Seed instantly from cache so the UI doesn't flash an empty state while the
        // first fresh compute runs (or never runs, in tests with autoCompute=false).
        self.currentBalance = cacheStore.cachedBalance
        if autoCompute {
            try? recomputeNow()
        }
        if autoObserve {
            startObserving()
        }
        // Subscribe to CloudKit import-finish events. Each event coalesces into the
        // same 200ms debounce window as willSave-driven recomputes — so a burst that
        // includes both a local insert and a remote import settles into one recompute.
        if let importEventPublisher {
            self.importSubscription = importEventPublisher.sink { [weak self] in
                Task { @MainActor [weak self] in
                    self?.scheduleRecompute()
                }
            }
        }
    }

    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
        debounceTask?.cancel()
        importSubscription?.cancel()
    }

    // MARK: - Compute

    /// Stateless compute against the current model context. Returns `nil` if no anchor exists.
    func computeBalance() throws -> Double? {
        guard let anchor = try fetchAnchor() else { return nil }
        let anchorDate = anchor.anchorDate
        let predicate = #Predicate<Transaction> { $0.date >= anchorDate }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        let transactions = try modelContext.fetch(descriptor)
        let delta = transactions.reduce(0.0) { acc, tx in
            switch tx.type {
            case .income: return acc + tx.amount
            case .expense: return acc - tx.amount
            }
        }
        return anchor.openingBalance + delta
    }

    /// Recompute immediately and update `currentBalance` + the per-device cache.
    /// Idempotent. When `computeBalance()` returns `nil` (no anchor), the cache is
    /// cleared so the UI doesn't show a stale value for a user who removed setup.
    func recomputeNow() throws {
        let result = try computeBalance()
        currentBalance = result
        recomputeCount += 1
        if let value = result {
            cacheStore.write(balance: value)
        } else {
            cacheStore.clear()
        }
    }

    /// Schedule a debounced recompute. Subsequent calls within the 200ms window cancel
    /// the prior task — only the last one fires.
    func scheduleRecompute() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled, let self else { return }
            try? self.recomputeNow()
        }
    }

    // MARK: - Observer

    func startObserving() {
        guard observerToken == nil else { return }
        observerToken = NotificationCenter.default.addObserver(
            forName: ModelContext.willSave,
            object: modelContext,
            queue: nil
        ) { [weak self] _ in
            // willSave fires synchronously on the saving thread (MainActor in our setup).
            // We must check the pending-model arrays here, *before* save() returns and
            // clears them. Hopping to a Task @MainActor would land after save completes,
            // by which point `insertedModelsArray` etc. are empty.
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.contextAffectsTransactions() else { return }
                self.scheduleRecompute()
            }
        }
    }

    func stopObserving() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
    }

    /// Inspect the model context's pending changes for Transaction inserts/updates/deletes.
    /// Must be called on MainActor (the context is MainActor-isolated in our setup).
    private func contextAffectsTransactions() -> Bool {
        let inserted = modelContext.insertedModelsArray
        if inserted.contains(where: { $0 is Transaction }) { return true }
        let changed = modelContext.changedModelsArray
        if changed.contains(where: { $0 is Transaction }) { return true }
        let deleted = modelContext.deletedModelsArray
        if deleted.contains(where: { $0 is Transaction }) { return true }
        return false
    }

    // MARK: - Anchor fetch (with multi-row recovery)

    private func fetchAnchor() throws -> BalanceAnchor? {
        let descriptor = FetchDescriptor<BalanceAnchor>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let anchors = try modelContext.fetch(descriptor)
        guard let oldest = anchors.first else { return nil }
        if anchors.count > 1 {
            for extra in anchors.dropFirst() {
                modelContext.delete(extra)
            }
            try? modelContext.save()
        }
        return oldest
    }
}

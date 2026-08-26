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
/// Formula: `balance = openingBalance + Σ(post-anchor transaction amounts) + Σ(adjustments)`
@MainActor
@Observable
final class BalanceService {
    /// Latest computed balance. `nil` means no anchor exists yet (user hasn't set up balance).
    private(set) var currentBalance: Double?

    /// Published balances for non-Personal wallets that have been affected by a
    /// local edit or reconciled after a save. Reading through `currentBalance(for:)`
    /// observes this map so wallet-scoped UI refreshes when either side of a move changes.
    private(set) var walletBalances: [String: Double] = [:]

    /// Recompute counter — used by tests and useful for diagnostics.
    private(set) var recomputeCount: Int = 0

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let cacheStore: BalanceCacheStore
    @ObservationIgnored private var observerToken: NSObjectProtocol?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var importSubscription: AnyCancellable?
    /// Cached anchor dates from the last successful compute per wallet. Lets
    /// `applyOptimistic*` decide inclusion without a SwiftData fetch on every
    /// CRUD call, while keeping non-Personal balance reads from affecting
    /// Personal optimistic updates.
    @ObservationIgnored private var cachedAnchorDates: [String: Date] = [:]
    /// Wallets whose balances have been read or mutated during this service lifetime.
    /// Reconciliation refreshes this set without having to query Wallet rows.
    @ObservationIgnored private var knownWalletIds: Set<String> = [Wallet.personalID]

    /// 200ms — coalesces notification bursts (CloudKit import, rapid CRUD).
    static let debounceInterval: Duration = .milliseconds(200)

    convenience init(
        modelContext: ModelContext,
        importEventPublisher: AnyPublisher<Void, Never>? = nil,
        autoObserve: Bool = true,
        autoCompute: Bool = true
    ) {
        self.init(
            modelContext: modelContext,
            cacheStore: BalanceCacheStore(),
            importEventPublisher: importEventPublisher,
            autoObserve: autoObserve,
            autoCompute: autoCompute
        )
    }

    init(
        modelContext: ModelContext,
        cacheStore: BalanceCacheStore,
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
                    guard let self else { return }
                    do {
                        _ = try WalletService.bootstrapIfNeeded(modelContext: self.modelContext)
                    } catch {
                        print("[WalletService] cloud-import-event repair failed: \(error)")
                    }
                    self.scheduleRecompute()
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
    ///
    /// Predicate uses `Transaction.createdAt` (immutable creation instant) rather than
    /// `Transaction.date` (user-picked, defaults to noon-of-day in TransactionFormView).
    /// `.date` is for display/grouping; `.createdAt` is for inclusion. This means:
    ///   - User sets balance at 3pm → anchor = 3pm.
    ///   - User logs an expense at 4pm (date defaults to noon-today) → createdAt = 4pm
    ///     ≥ anchor → INCLUDED. The noon `.date` would have been excluded under the
    ///     old `date >= anchorDate` predicate.
    ///   - User backfills yesterday's coffee at 4pm → createdAt = 4pm ≥ anchor →
    ///     INCLUDED. The user-stated date doesn't change whether the entry reduces
    ///     the running balance: it's still real money out, just logged late.
    func computeBalance() throws -> Double? {
        try computeBalance(walletId: Wallet.personalID)
    }

    func computeBalance(walletId: String) throws -> Double? {
        knownWalletIds.insert(walletId)
        guard let anchor = try fetchAnchor(walletId: walletId) else {
            cachedAnchorDates[walletId] = nil
            return nil
        }
        let anchorDate = anchor.anchorDate
        cachedAnchorDates[walletId] = anchorDate
        let predicate = #Predicate<Transaction> {
            $0.createdAt >= anchorDate && $0.walletId == walletId
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        let transactions = try modelContext.fetch(descriptor)
        let delta = transactions.reduce(0.0) { acc, tx in
            switch tx.type {
            case .income: return acc + tx.amount
            case .expense: return acc - tx.amount
            }
        }
        let adjustmentPredicate = #Predicate<BalanceAdjustment> {
            $0.walletId == walletId
        }
        let adjustments = try modelContext.fetch(
            FetchDescriptor<BalanceAdjustment>(predicate: adjustmentPredicate)
        )
        let adjustmentDelta = adjustments.reduce(0.0) { $0 + $1.amount }
        return anchor.openingBalance + delta + adjustmentDelta
    }

    func computeTotalBalance(walletIds: [String]) throws -> Double? {
        var total = 0.0
        var hasAnyBalance = false
        for walletId in walletIds {
            if let walletBalance = try computeBalance(walletId: walletId) {
                total += walletBalance
                hasAnyBalance = true
            }
        }
        return hasAnyBalance ? total : nil
    }

    func currentBalance(for walletId: String) -> Double? {
        if walletId == Wallet.personalID {
            return currentBalance
        }
        if let published = walletBalances[walletId] {
            return published
        }
        return try? computeBalance(walletId: walletId)
    }

    func authoritativeBalances(for walletIds: Set<String>) throws -> [String: Double] {
        var balances: [String: Double] = [:]
        for walletId in walletIds {
            if let balance = try computeBalance(walletId: walletId) {
                balances[walletId] = balance
            }
        }
        return balances
    }

    func publish(_ balances: [String: Double]) {
        for (walletId, balance) in balances {
            knownWalletIds.insert(walletId)
            setPublishedBalance(balance, for: walletId)
        }
    }

    // MARK: - Optimistic updates

    /// Apply a newly inserted transaction to the running balance in O(1).
    /// Call right after `modelContext.insert(tx)`. The willSave observer still
    /// schedules a debounced full recompute as a reconciliation backstop.
    ///
    /// No-op when no anchor exists (balance feature isn't set up) or when the
    /// transaction predates the anchor (excluded by the compute predicate).
    func applyOptimisticInsert(_ tx: Transaction) {
        guard tx.walletId == Wallet.personalID else { return }
        guard let current = currentBalance, let anchorDate = cachedAnchorDates[Wallet.personalID] else { return }
        guard tx.createdAt >= anchorDate else { return }
        let signed = signedAmount(amount: tx.amount, type: tx.type)
        currentBalance = current + signed
        cacheStore.write(balance: current + signed)
    }

    /// Apply a pending deletion to the running balance in O(1).
    /// Call *before* `modelContext.delete(tx)` (or pass a snapshot of its fields)
    /// so the values are still readable.
    func applyOptimisticDelete(_ tx: Transaction) {
        guard tx.walletId == Wallet.personalID else { return }
        guard let current = currentBalance, let anchorDate = cachedAnchorDates[Wallet.personalID] else { return }
        guard tx.createdAt >= anchorDate else { return }
        let signed = signedAmount(amount: tx.amount, type: tx.type)
        currentBalance = current - signed
        cacheStore.write(balance: current - signed)
    }

    /// Apply an in-place edit. Pass the *old* amount/type captured before mutation
    /// and the *new* amount/type after mutation, along with the transaction's
    /// `createdAt` (which doesn't change on edit).
    func applyOptimisticEdit(
        createdAt: Date,
        oldAmount: Double,
        oldType: TransactionType,
        oldWalletId: String = Wallet.personalID,
        newAmount: Double,
        newType: TransactionType,
        newWalletId: String = Wallet.personalID
    ) {
        knownWalletIds.insert(oldWalletId)
        knownWalletIds.insert(newWalletId)

        // The caller has already mutated the Transaction. Recompute each affected
        // non-Personal wallet from the current context and publish the result so
        // observers refresh both the source and destination wallet immediately.
        let affectedNonPersonalWallets = Set([oldWalletId, newWalletId])
            .filter { $0 != Wallet.personalID }
        for walletId in affectedNonPersonalWallets {
            refreshPublishedBalance(for: walletId)
        }

        // Personal keeps its existing O(1) optimistic path and per-device cache.
        guard oldWalletId == Wallet.personalID || newWalletId == Wallet.personalID else { return }
        guard let current = currentBalance, let anchorDate = cachedAnchorDates[Wallet.personalID] else { return }
        guard createdAt >= anchorDate else { return }
        let oldContribution = oldWalletId == Wallet.personalID
            ? signedAmount(amount: oldAmount, type: oldType)
            : 0
        let newContribution = newWalletId == Wallet.personalID
            ? signedAmount(amount: newAmount, type: newType)
            : 0
        let delta = newContribution - oldContribution
        guard delta != 0 else { return }
        currentBalance = current + delta
        cacheStore.write(balance: current + delta)
    }

    private func refreshPublishedBalance(for walletId: String) {
        do {
            setPublishedBalance(try computeBalance(walletId: walletId), for: walletId)
        } catch {
            // Keep the edit flow non-throwing. The pending save observer will retry
            // all known wallets through the normal debounced reconciliation path.
            scheduleRecompute()
        }
    }

    private func setPublishedBalance(_ balance: Double?, for walletId: String) {
        if walletId == Wallet.personalID {
            currentBalance = balance
            if let balance {
                cacheStore.write(balance: balance)
            } else {
                cacheStore.clear()
            }
            return
        }

        if let balance {
            walletBalances[walletId] = balance
        } else {
            walletBalances.removeValue(forKey: walletId)
        }
    }

    private func signedAmount(amount: Double, type: TransactionType) -> Double {
        switch type {
        case .income:  return amount
        case .expense: return -amount
        }
    }

    /// Recompute immediately and update `currentBalance` + the per-device cache.
    /// Idempotent. When `computeBalance()` returns `nil` (no anchor), the cache is
    /// cleared so the UI doesn't show a stale value for a user who removed setup.
    ///
    /// Runs duplicate-anchor recovery first so the compute path stays a pure read.
    func recomputeNow() throws {
        try recoverDuplicateAnchorsIfNeeded()
        let walletIds = knownWalletIds
        for walletId in walletIds {
            setPublishedBalance(try computeBalance(walletId: walletId), for: walletId)
        }
        recomputeCount += 1
    }

    /// Treat `amount` as the wallet's balance at `date`. The first setup creates
    /// an anchor. Later reconciliations append a signed correction and preserve
    /// the original anchor so future transaction edits have a stable baseline.
    func setCurrentBalance(
        _ amount: Double,
        for walletId: String,
        at date: Date = .now,
        save: @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        // Do not run the repair path here: it performs its own save and could
        // commit unrelated wallet metadata before this reconciliation is ready.
        // `fetchAnchor` already deterministically uses the oldest anchor, while
        // startup/debounced recomputation handles duplicate cleanup separately.
        var insertedAdjustment: BalanceAdjustment?
        var insertedAnchor: BalanceAnchor?

        if let existing = try fetchAnchor(walletId: walletId) {
            let current = try computeBalance(walletId: walletId) ?? existing.openingBalance
            let delta = amount - current
            if abs(delta) > 0.000_001 {
                let operationId = UUID().uuidString
                let adjustment = BalanceAdjustment(
                    id: "\(operationId):\(walletId)",
                    operationId: operationId,
                    walletId: walletId,
                    amount: delta,
                    reason: .manualReconciliation
                )
                modelContext.insert(adjustment)
                insertedAdjustment = adjustment
            }
        } else {
            let anchor = BalanceAnchor(
                walletId: walletId,
                openingBalance: amount,
                anchorDate: date
            )
            modelContext.insert(anchor)
            insertedAnchor = anchor
        }

        do {
            try save(modelContext)
        } catch {
            if let insertedAdjustment { modelContext.delete(insertedAdjustment) }
            if let insertedAnchor { modelContext.delete(insertedAnchor) }
            throw error
        }
        knownWalletIds.insert(walletId)
        if cachedAnchorDates[walletId] == nil {
            cachedAnchorDates[walletId] = try fetchAnchor(walletId: walletId)?.anchorDate
        }
        setPublishedBalance(amount, for: walletId)
    }

    /// Explicit wipe used by "Delete All Data" so the cache + observable state
    /// match the now-empty SwiftData store. The willSave observer can't catch
    /// `ModelContext.delete(model:)` batch deletes (they bypass the normal
    /// pending-changes path), so SettingsView calls this directly after the wipe.
    func clearAll() {
        currentBalance = nil
        walletBalances.removeAll()
        cachedAnchorDates.removeAll()
        knownWalletIds = [Wallet.personalID]
        cacheStore.clear()
        recomputeCount += 1
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
                guard self.contextAffectsBalanceInputs() else { return }
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

    /// Inspect the model context's pending changes for transaction, anchor, or adjustment
    /// inserts/updates/deletes. Both affect the running balance: Transaction changes
    /// shift the sum, BalanceAnchor changes shift the opening value or anchor moment.
    /// Must be called on MainActor (the context is MainActor-isolated in our setup).
    private func contextAffectsBalanceInputs() -> Bool {
        func matches(_ model: any PersistentModel) -> Bool {
            model is Transaction || model is BalanceAnchor || model is BalanceAdjustment
        }
        if modelContext.insertedModelsArray.contains(where: matches) { return true }
        if modelContext.changedModelsArray.contains(where: matches) { return true }
        if modelContext.deletedModelsArray.contains(where: matches) { return true }
        return false
    }

    // MARK: - Anchor fetch (pure read)

    /// Pure read — returns the oldest anchor by `createdAt`. No side effects, no
    /// saves. Duplicate-row recovery is a separate step run from `recomputeNow`.
    private func fetchAnchor() throws -> BalanceAnchor? {
        try fetchAnchor(walletId: Wallet.personalID)
    }

    private func fetchAnchor(walletId: String) throws -> BalanceAnchor? {
        let descriptor = FetchDescriptor<BalanceAnchor>(
            predicate: #Predicate { $0.walletId == walletId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let anchors = try modelContext.fetch(descriptor)
        return anchors.first
    }

    // MARK: - Duplicate-anchor recovery

    /// If more than one BalanceAnchor row exists (CloudKit last-writer-wins race),
    /// keep the oldest by `createdAt` and delete the rest. `@Attribute(.unique)`
    /// can't be used with CloudKit-synced models, so we deconflict at the app layer.
    private func recoverDuplicateAnchorsIfNeeded() throws {
        let descriptor = FetchDescriptor<BalanceAnchor>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let anchors = try modelContext.fetch(descriptor)
        let grouped = Dictionary(grouping: anchors) { $0.walletId }
        var didRepair = false
        for walletAnchors in grouped.values where walletAnchors.count > 1 {
            for extra in walletAnchors.dropFirst() {
                modelContext.delete(extra)
                didRepair = true
            }
        }
        if didRepair {
            try modelContext.save()
        }
    }
}

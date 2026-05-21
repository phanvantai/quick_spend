import Foundation

/// Per-device cache for the user's computed account balance.
///
/// Backed by `UserDefaults` so it survives app launches but is **not** synced via
/// CloudKit — that prevents the flip-flop you'd get when two devices race to write
/// their own freshly-computed value under last-writer-wins. The source-of-truth
/// fields (`openingBalance`, `anchorDate`) live on the synced `BalanceAnchor` model.
///
/// Cache is consumed on cold start so the UI can render instantly with the last-known
/// value while `BalanceService` runs the fresh compute.
final class BalanceCacheStore {
    private let defaults: UserDefaults

    private static let balanceKey = "balance.cachedBalance"
    private static let timestampKey = "balance.lastComputedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The most recently computed balance, or `nil` if nothing has been written
    /// (e.g. fresh install, or `clear()` after the anchor was removed).
    var cachedBalance: Double? {
        guard defaults.object(forKey: Self.balanceKey) != nil else { return nil }
        return defaults.double(forKey: Self.balanceKey)
    }

    /// Timestamp of the last successful write, used by the UI to show a "stale" hint
    /// during CloudKit syncs (planned for a later layer).
    var lastComputedAt: Date? {
        defaults.object(forKey: Self.timestampKey) as? Date
    }

    func write(balance: Double, at date: Date = .now) {
        defaults.set(balance, forKey: Self.balanceKey)
        defaults.set(date, forKey: Self.timestampKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.balanceKey)
        defaults.removeObject(forKey: Self.timestampKey)
    }
}

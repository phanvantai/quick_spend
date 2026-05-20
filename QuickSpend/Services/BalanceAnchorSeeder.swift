import Foundation
import SwiftData

/// Seeds an initial `BalanceAnchor` row when none exists, so the `BalanceCard`
/// renders in display state on Home immediately after onboarding finishes.
///
/// Idempotent — calling it more than once never creates additional rows. Also
/// called from the SplashView "skip onboarding because CloudKit synced data
/// found" path so devices that join later still get an anchor if their iCloud
/// snapshot pre-dates this feature.
enum BalanceAnchorSeeder {
    /// Inserts a zero-balance anchor with `anchorDate = startOfDay(now)` if and
    /// only if no anchor row exists in the context. Returns `true` if it inserted.
    @discardableResult
    static func seedIfNeeded(modelContext: ModelContext, now: Date = .now) -> Bool {
        let descriptor = FetchDescriptor<BalanceAnchor>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return false }

        let anchor = BalanceAnchor(
            openingBalance: 0,
            anchorDate: Calendar.current.startOfDay(for: now)
        )
        modelContext.insert(anchor)
        try? modelContext.save()
        return true
    }
}

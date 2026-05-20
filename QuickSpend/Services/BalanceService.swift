import Foundation
import SwiftData

/// Computes the user's current account balance from `BalanceAnchor` + `Transaction` history.
///
/// Minimal Layer 1: synchronous compute against the model context. Caching, debouncing,
/// willSave hook, CloudKit didFinishImport wire-up, and defensive multi-row recovery
/// land in later layers (see plan).
///
/// Formula: `balance = openingBalance + Σ(income where date >= anchorDate) − Σ(expense where date >= anchorDate)`
@MainActor
final class BalanceService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Returns the current balance, or `nil` if no anchor exists (user hasn't set up balance yet).
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

    /// Returns the singleton anchor row if it exists.
    private func fetchAnchor() throws -> BalanceAnchor? {
        let descriptor = FetchDescriptor<BalanceAnchor>()
        let anchors = try modelContext.fetch(descriptor)
        return anchors.first
    }
}

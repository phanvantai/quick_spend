import Foundation
import SwiftData

/// Anchor point for the user's account balance.
/// `openingBalance` + sum of transactions with `date >= anchorDate` = current balance.
///
/// Uses a fixed UUID so CloudKit cannot produce two anchor rows under last-writer-wins.
/// Synced fields only — the computed/cached balance lives in UserDefaults per-device.
@Model
final class BalanceAnchor {
    /// Singleton row identifier. Always this UUID; defensive recovery deletes any extras.
    static let singletonID = "00000000-0000-0000-0000-000000000001"

    var id: String = BalanceAnchor.singletonID
    var openingBalance: Double = 0
    var anchorDate: Date = Date.now
    var createdAt: Date = Date.now

    init(
        id: String = BalanceAnchor.singletonID,
        openingBalance: Double,
        anchorDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.openingBalance = openingBalance
        self.anchorDate = anchorDate
        self.createdAt = createdAt
    }
}

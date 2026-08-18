import Foundation
import SwiftData

/// Anchor point for the user's account balance.
/// `openingBalance` + sum of transactions with `date >= anchorDate` = current balance.
///
/// Uses a fixed UUID so CloudKit cannot produce two anchor rows under last-writer-wins.
/// Synced fields only — the computed/cached balance lives in UserDefaults per-device.
@Model
final class BalanceAnchor {
    /// Legacy singleton row identifier used before wallets existed.
    static let legacySingletonID = "00000000-0000-0000-0000-000000000001"
    static let singletonID = legacySingletonID

    static func id(for walletId: String) -> String {
        "balance_anchor_\(walletId)"
    }

    var id: String = BalanceAnchor.id(for: Wallet.personalID)
    var walletId: String = Wallet.personalID
    var openingBalance: Double = 0
    var anchorDate: Date = Date.now
    var createdAt: Date = Date.now

    init(
        id: String? = nil,
        walletId: String = Wallet.personalID,
        openingBalance: Double,
        anchorDate: Date,
        createdAt: Date = .now
    ) {
        self.id = id ?? BalanceAnchor.id(for: walletId)
        self.walletId = walletId
        self.openingBalance = openingBalance
        self.anchorDate = anchorDate
        self.createdAt = createdAt
    }
}

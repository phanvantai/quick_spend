import Foundation
import SwiftData

enum BalanceAdjustmentReason: String, Codable, CaseIterable {
    case manualReconciliation = "manual_reconciliation"
    case transactionEdit = "transaction_edit"
    case transactionDelete = "transaction_delete"
}

/// Immutable signed correction applied on top of a wallet's anchor ledger.
@Model
final class BalanceAdjustment {
    var id: String = ""
    var operationId: String = ""
    var walletId: String = Wallet.personalID
    var amount: Double = 0
    var reason: String = BalanceAdjustmentReason.manualReconciliation.rawValue
    var sourceTransactionId: String?
    var createdAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        operationId: String = UUID().uuidString,
        walletId: String,
        amount: Double,
        reason: BalanceAdjustmentReason,
        sourceTransactionId: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.operationId = operationId
        self.walletId = walletId
        self.amount = amount
        self.reason = reason.rawValue
        self.sourceTransactionId = sourceTransactionId
        self.createdAt = createdAt
    }
}

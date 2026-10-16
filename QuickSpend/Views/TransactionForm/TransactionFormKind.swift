import Foundation

/// What the transaction form is entering: a categorized expense or income, or
/// a transfer between two wallets.
enum TransactionFormKind: Hashable {
    case expense
    case income
    case transfer

    init(_ type: TransactionType) {
        self = type == .income ? .income : .expense
    }

    var transactionType: TransactionType? {
        switch self {
        case .expense: return .expense
        case .income: return .income
        case .transfer: return nil
        }
    }

    /// Segments the form's toggle shows. Transfers need somewhere to save them
    /// and a second wallet; an existing row keeps its kind family.
    static func available(
        editing: TransactionFormKind?,
        canTransfer: Bool,
        activeWalletCount: Int
    ) -> [TransactionFormKind] {
        switch editing {
        case .transfer:
            return [.transfer]
        case .expense, .income:
            return [.expense, .income]
        case nil:
            return canTransfer && activeWalletCount > 1 ? [.expense, .income, .transfer] : [.expense, .income]
        }
    }
}

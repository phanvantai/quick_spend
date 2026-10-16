import Foundation

/// Which side of a wallet-to-wallet transfer a transaction row represents.
enum TransferLeg: String {
    case outgoing = "out"
    case incoming = "in"
}

/// Money moved between two of the user's wallets.
///
/// Stored as two ordinary `Transaction` rows so no schema change is needed and
/// wallet balances stay correct through the existing balance ledger:
/// - an `.expense` leg in the source wallet (`transfer:<id>:out`)
/// - an `.income` leg in the destination wallet (`transfer:<id>:in`)
///
/// Both legs use `Transfer.categoryId`, which marks them as transfers so
/// income/expense totals and reports leave them out. Older app versions see
/// them as uncategorized income/expense, which keeps balances right.
struct Transfer: Equatable, Identifiable {
    /// Not a user-creatable id: user categories get ids from their name, which
    /// cannot produce the "system." prefix.
    static let categoryId = "system.transfer"
    static let iconName = "arrow.left.arrow.right"

    private static let legIdPrefix = "transfer"

    let id: String
    var fromWalletId: String
    var toWalletId: String
    var amount: Double
    var date: Date
    var note: String

    init(
        id: String = UUID().uuidString,
        fromWalletId: String,
        toWalletId: String,
        amount: Double,
        date: Date,
        note: String = ""
    ) {
        self.id = id
        self.fromWalletId = fromWalletId
        self.toWalletId = toWalletId
        self.amount = amount
        self.date = date
        self.note = note
    }

    var isValid: Bool {
        amount > 0 && !fromWalletId.isEmpty && !toWalletId.isEmpty && fromWalletId != toWalletId
    }

    static func legId(transferId: String, leg: TransferLeg) -> String {
        "\(legIdPrefix):\(transferId):\(leg.rawValue)"
    }

    /// The two rows to persist, outgoing first.
    func makeLegs(createdAt: Date = .now) -> [Transaction] {
        [
            Transaction(
                id: Self.legId(transferId: id, leg: .outgoing),
                amount: amount,
                note: note,
                categoryId: Self.categoryId,
                walletId: fromWalletId,
                type: .expense,
                date: date,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Transaction(
                id: Self.legId(transferId: id, leg: .incoming),
                amount: amount,
                note: note,
                categoryId: Self.categoryId,
                walletId: toWalletId,
                type: .income,
                date: date,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
        ]
    }

    /// Rebuilds a transfer from whichever of its legs exist. A missing leg
    /// (e.g. not yet synced) leaves that side's wallet empty so the edit form
    /// can ask for it and saving recreates the leg.
    init?(legs: [Transaction]) {
        let transferLegs = legs.filter(\.isTransfer)
        guard let first = transferLegs.first, let transferId = first.transferId else { return nil }
        let out = transferLegs.first { $0.transferLeg == .outgoing }
        let incoming = transferLegs.first { $0.transferLeg == .incoming }
        self.init(
            id: transferId,
            fromWalletId: out?.walletId ?? "",
            toWalletId: incoming?.walletId ?? "",
            amount: first.amount,
            date: first.date,
            note: first.note
        )
    }

    /// Parses `transfer:<id>:<leg>` leg ids.
    fileprivate static func parse(legId: String) -> (transferId: String, leg: TransferLeg)? {
        let parts = legId.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0] == Substring(legIdPrefix),
              !parts[1].isEmpty,
              let leg = TransferLeg(rawValue: String(parts[2])) else { return nil }
        return (String(parts[1]), leg)
    }
}

extension Transaction {
    var isTransfer: Bool { categoryId == Transfer.categoryId }

    var transferId: String? {
        guard isTransfer else { return nil }
        return Transfer.parse(legId: id)?.transferId
    }

    var transferLeg: TransferLeg? {
        guard isTransfer else { return nil }
        return Transfer.parse(legId: id)?.leg
    }

    var transferCounterpartId: String? {
        guard isTransfer, let parsed = Transfer.parse(legId: id) else { return nil }
        let other: TransferLeg = parsed.leg == .outgoing ? .incoming : .outgoing
        return Transfer.legId(transferId: parsed.transferId, leg: other)
    }
}

extension Sequence where Element == Transaction {
    /// Real income and expenses only — what totals, charts, and reports count.
    func excludingTransfers() -> [Transaction] {
        filter { !$0.isTransfer }
    }
}

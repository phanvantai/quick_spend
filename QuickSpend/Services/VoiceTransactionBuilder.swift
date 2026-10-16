import Foundation

/// Turns parsed voice results into the rows to save: one `Transaction` per
/// expense or income, two legs per wallet transfer. Shared by the in-app
/// auto-save and Siri so both store the same thing.
enum VoiceTransactionBuilder {
    enum BuildError: Error, Equatable {
        /// A transfer has no destination wallet, or the same source and destination.
        case incompleteTransfer
    }

    static func transactions(
        from parsed: [ParsedTransaction],
        defaultWalletId: String
    ) throws -> [Transaction] {
        try parsed.flatMap { item -> [Transaction] in
            let walletId = item.walletId ?? defaultWalletId
            if let destination = item.transferToWalletId {
                guard !destination.isEmpty, destination != walletId else {
                    throw BuildError.incompleteTransfer
                }
                return Transfer(
                    fromWalletId: walletId,
                    toWalletId: destination,
                    amount: item.amount,
                    date: item.date,
                    note: item.note
                ).makeLegs()
            }
            return [Transaction(
                amount: item.amount,
                note: item.note,
                categoryId: item.categoryId,
                walletId: walletId,
                type: item.type,
                date: item.date,
                rawInput: item.rawInput,
                confidence: item.confidence
            )]
        }
    }
}

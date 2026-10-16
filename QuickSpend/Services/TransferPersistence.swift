import Foundation
import SwiftData

/// Creates, edits, and deletes wallet transfers. Both legs always change in a
/// single save so the two wallets can never disagree.
@MainActor
enum TransferPersistence {
    enum TransferError: Error, Equatable {
        case invalidTransfer
    }

    static func create(
        _ transfer: Transfer,
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: TransactionPersistence.SaveContext = { try $0.save() }
    ) throws {
        guard transfer.isValid else { throw TransferError.invalidTransfer }
        try TransactionPersistence.replace(
            removing: [],
            inserting: transfer.makeLegs(),
            modelContext: modelContext,
            balanceService: balanceService,
            save: save
        )
    }

    /// Replaces the existing legs (one or both) with legs for `transfer`,
    /// recreating a missing leg and keeping the original creation date.
    static func update(
        legs existing: [Transaction],
        to transfer: Transfer,
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: TransactionPersistence.SaveContext = { try $0.save() }
    ) throws {
        guard transfer.isValid else { throw TransferError.invalidTransfer }
        let createdAt = existing.map(\.createdAt).min() ?? .now
        let legs = transfer.makeLegs(createdAt: createdAt)
        legs.forEach { $0.updatedAt = .now }
        try TransactionPersistence.replace(
            removing: existing,
            inserting: legs,
            modelContext: modelContext,
            balanceService: balanceService,
            save: save
        )
    }

    static func delete(
        legs: [Transaction],
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: TransactionPersistence.SaveContext = { try $0.save() }
    ) throws {
        try TransactionPersistence.replace(
            removing: legs,
            inserting: [],
            modelContext: modelContext,
            balanceService: balanceService,
            save: save
        )
    }

    static func legs(transferId: String, modelContext: ModelContext) throws -> [Transaction] {
        let outId = Transfer.legId(transferId: transferId, leg: .outgoing)
        let inId = Transfer.legId(transferId: transferId, leg: .incoming)
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == outId || $0.id == inId }
        )
        return try modelContext.fetch(descriptor)
    }
}

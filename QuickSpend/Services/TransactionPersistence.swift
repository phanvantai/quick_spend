import Foundation
import SwiftData

@MainActor
enum TransactionPersistence {
    typealias SaveContext = @MainActor (ModelContext) throws -> Void

    private struct Snapshot {
        let id: String
        let amount: Double
        let note: String
        let categoryId: String
        let walletId: String
        let type: TransactionType
        let date: Date
        let rawInput: String?
        let confidence: Double?
        let createdAt: Date
        let updatedAt: Date

        init(_ transaction: Transaction) {
            id = transaction.id
            amount = transaction.amount
            note = transaction.note
            categoryId = transaction.categoryId
            walletId = transaction.walletId
            type = transaction.type
            date = transaction.date
            rawInput = transaction.rawInput
            confidence = transaction.confidence
            createdAt = transaction.createdAt
            updatedAt = transaction.updatedAt
        }

        func restore(_ transaction: Transaction) {
            transaction.amount = amount
            transaction.note = note
            transaction.categoryId = categoryId
            transaction.walletId = walletId
            transaction.type = type
            transaction.date = date
            transaction.rawInput = rawInput
            transaction.confidence = confidence
            transaction.createdAt = createdAt
            transaction.updatedAt = updatedAt
        }

        func restoredTransaction() -> Transaction {
            Transaction(
                id: id,
                amount: amount,
                note: note,
                categoryId: categoryId,
                walletId: walletId,
                type: type,
                date: date,
                rawInput: rawInput,
                confidence: confidence,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    static func create(
        _ transaction: Transaction,
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: SaveContext = { try $0.save() }
    ) throws {
        let walletIds = Set([transaction.walletId])
        let before = try balanceService.authoritativeBalances(for: walletIds)
        let targets = applying(
            before: before,
            old: nil,
            new: (transaction.walletId, signedAmount(of: transaction))
        )
        var adjustments: [BalanceAdjustment] = []
        modelContext.insert(transaction)
        do {
            adjustments = try insertAdjustments(
                for: targets,
                natural: balanceService.authoritativeBalances(for: walletIds),
                reason: .transactionEdit,
                transactionId: transaction.id,
                modelContext: modelContext
            )
            try save(modelContext)
            publishAfterSave(targets, walletIds: walletIds, balanceService: balanceService)
        } catch {
            adjustments.forEach(modelContext.delete)
            modelContext.delete(transaction)
            balanceService.publish(before)
            throw error
        }
    }

    static func createMany(
        _ transactions: [Transaction],
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: SaveContext = { try $0.save() }
    ) throws {
        guard !transactions.isEmpty else { return }
        let walletIds = Set(transactions.map(\.walletId))
        let before = try balanceService.authoritativeBalances(for: walletIds)
        var targets = before
        for transaction in transactions {
            guard targets[transaction.walletId] != nil else { continue }
            targets[transaction.walletId, default: 0] += signedAmount(of: transaction)
        }
        transactions.forEach(modelContext.insert)
        do {
            let adjustments = try insertAdjustments(
                for: targets,
                natural: balanceService.authoritativeBalances(for: walletIds),
                reason: .transactionEdit,
                transactionId: nil,
                modelContext: modelContext
            )
            do {
                try save(modelContext)
                publishAfterSave(targets, walletIds: walletIds, balanceService: balanceService)
            } catch {
                adjustments.forEach(modelContext.delete)
                throw error
            }
        } catch {
            transactions.forEach(modelContext.delete)
            balanceService.publish(before)
            throw error
        }
    }

    static func update(
        _ transaction: Transaction,
        with updated: Transaction,
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: SaveContext = { try $0.save() }
    ) throws {
        let snapshot = Snapshot(transaction)
        let walletIds = Set([snapshot.walletId, updated.walletId])
        let before = try balanceService.authoritativeBalances(for: walletIds)
        let targets = applying(
            before: before,
            old: (snapshot.walletId, signedAmount(amount: snapshot.amount, type: snapshot.type)),
            new: (updated.walletId, signedAmount(of: updated))
        )

        transaction.amount = updated.amount
        transaction.note = updated.note
        transaction.categoryId = updated.categoryId
        transaction.walletId = updated.walletId
        transaction.type = updated.type
        transaction.date = updated.date
        transaction.rawInput = updated.rawInput
        transaction.confidence = updated.confidence
        transaction.updatedAt = .now

        var adjustments: [BalanceAdjustment] = []
        do {
            adjustments = try insertAdjustments(
                for: targets,
                natural: balanceService.authoritativeBalances(for: walletIds),
                reason: .transactionEdit,
                transactionId: transaction.id,
                modelContext: modelContext
            )
            try save(modelContext)
            publishAfterSave(targets, walletIds: walletIds, balanceService: balanceService)
        } catch {
            adjustments.forEach(modelContext.delete)
            snapshot.restore(transaction)
            balanceService.publish(before)
            throw error
        }
    }

    static func delete(
        _ transaction: Transaction,
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: SaveContext = { try $0.save() }
    ) throws {
        let snapshot = Snapshot(transaction)
        let walletIds = Set([snapshot.walletId])
        let before = try balanceService.authoritativeBalances(for: walletIds)
        let targets = applying(
            before: before,
            old: (snapshot.walletId, signedAmount(amount: snapshot.amount, type: snapshot.type)),
            new: nil
        )
        var adjustments: [BalanceAdjustment] = []
        modelContext.delete(transaction)
        do {
            adjustments = try insertAdjustments(
                for: targets,
                natural: balanceService.authoritativeBalances(for: walletIds),
                reason: .transactionDelete,
                transactionId: transaction.id,
                modelContext: modelContext
            )
            try save(modelContext)
            publishAfterSave(targets, walletIds: walletIds, balanceService: balanceService)
        } catch {
            adjustments.forEach(modelContext.delete)
            // SwiftData does not revive a pending-deleted model when the same
            // instance is inserted again. Restore an equivalent row instead.
            modelContext.insert(snapshot.restoredTransaction())
            balanceService.publish(before)
            throw error
        }
    }

    /// Deletes `removing` and inserts `inserting` in one save, reconciling
    /// every wallet either side touches. Used for multi-row changes such as
    /// wallet transfers; on failure the store and balances are left as before.
    static func replace(
        removing: [Transaction],
        inserting: [Transaction],
        modelContext: ModelContext,
        balanceService: BalanceService,
        save: SaveContext = { try $0.save() }
    ) throws {
        guard !removing.isEmpty || !inserting.isEmpty else { return }
        let snapshots = removing.map(Snapshot.init)
        let walletIds = Set(snapshots.map(\.walletId) + inserting.map(\.walletId))
        let before = try balanceService.authoritativeBalances(for: walletIds)
        var targets = before
        for snapshot in snapshots where targets[snapshot.walletId] != nil {
            targets[snapshot.walletId, default: 0] -= signedAmount(amount: snapshot.amount, type: snapshot.type)
        }
        for transaction in inserting where targets[transaction.walletId] != nil {
            targets[transaction.walletId, default: 0] += signedAmount(of: transaction)
        }

        removing.forEach(modelContext.delete)
        inserting.forEach(modelContext.insert)
        var adjustments: [BalanceAdjustment] = []
        do {
            adjustments = try insertAdjustments(
                for: targets,
                natural: balanceService.authoritativeBalances(for: walletIds),
                reason: inserting.isEmpty ? .transactionDelete : .transactionEdit,
                transactionId: (inserting.first ?? removing.first)?.id,
                modelContext: modelContext
            )
            try save(modelContext)
            publishAfterSave(targets, walletIds: walletIds, balanceService: balanceService)
        } catch {
            adjustments.forEach(modelContext.delete)
            inserting.forEach(modelContext.delete)
            // Pending-deleted models are not revived by re-inserting the same
            // instance, so restore equivalent rows instead.
            snapshots.forEach { modelContext.insert($0.restoredTransaction()) }
            balanceService.publish(before)
            throw error
        }
    }

    /// Publishes the reconciled targets plus wallets that had no balance before
    /// this change (no starting balance and no activity) but have one now.
    private static func publishAfterSave(
        _ targets: [String: Double],
        walletIds: Set<String>,
        balanceService: BalanceService
    ) {
        var balances = targets
        for walletId in walletIds where balances[walletId] == nil {
            if let balance = try? balanceService.computeBalance(walletId: walletId) {
                balances[walletId] = balance
            }
        }
        balanceService.publish(balances)
    }

    private static func applying(
        before: [String: Double],
        old: (walletId: String, amount: Double)?,
        new: (walletId: String, amount: Double)?
    ) -> [String: Double] {
        var targets = before
        if let old, targets[old.walletId] != nil {
            targets[old.walletId, default: 0] -= old.amount
        }
        if let new, targets[new.walletId] != nil {
            targets[new.walletId, default: 0] += new.amount
        }
        return targets
    }

    private static func insertAdjustments(
        for targets: [String: Double],
        natural: [String: Double],
        reason: BalanceAdjustmentReason,
        transactionId: String?,
        modelContext: ModelContext
    ) throws -> [BalanceAdjustment] {
        let operationId = UUID().uuidString
        var inserted: [BalanceAdjustment] = []
        for walletId in targets.keys.sorted() {
            guard let target = targets[walletId], let current = natural[walletId] else { continue }
            let delta = target - current
            guard abs(delta) > 0.000_001 else { continue }
            let adjustment = BalanceAdjustment(
                id: "\(operationId):\(walletId)",
                operationId: operationId,
                walletId: walletId,
                amount: delta,
                reason: reason,
                sourceTransactionId: transactionId
            )
            modelContext.insert(adjustment)
            inserted.append(adjustment)
        }
        return inserted
    }

    private static func signedAmount(of transaction: Transaction) -> Double {
        signedAmount(amount: transaction.amount, type: transaction.type)
    }

    private static func signedAmount(amount: Double, type: TransactionType) -> Double {
        type == .income ? amount : -amount
    }
}

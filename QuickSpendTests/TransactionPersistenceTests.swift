import Foundation
import SwiftData
import Testing
@testable import QuickSpend

@Suite("Transaction Persistence Tests")
@MainActor
struct TransactionPersistenceTests {
    private enum InjectedFailure: Error { case save }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: configuration
        )
    }

    private func makeOnDiskContainer(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: AppSchema.schema,
            migrationPlan: QuickSpendMigrationPlan.self,
            configurations: ModelConfiguration(
                "TransactionPersistence",
                schema: AppSchema.schema,
                url: url,
                cloudKitDatabase: .none
            )
        )
    }

    @Test("Moving a pre-anchor expense changes both wallet balances and preserves their total")
    func movingPreAnchorExpenseReconcilesBothWallets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            id: "tx_pre_anchor",
            amount: 100,
            note: "Old expense",
            categoryId: "food",
            walletId: Wallet.personalID,
            type: .expense,
            createdAt: anchorDate.addingTimeInterval(-60)
        )
        context.insert(BalanceAnchor(walletId: Wallet.personalID, openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(BalanceAnchor(walletId: "wallet_side", openingBalance: 500, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        let updated = Transaction(
            id: transaction.id,
            amount: 100,
            note: "Old expense",
            categoryId: "food",
            walletId: "wallet_side",
            type: .expense,
            date: transaction.date
        )

        try TransactionPersistence.update(
            transaction,
            with: updated,
            modelContext: context,
            balanceService: balance
        )

        #expect(try balance.computeBalance(walletId: Wallet.personalID) == 1_100)
        #expect(try balance.computeBalance(walletId: "wallet_side") == 400)
        #expect(try balance.computeTotalBalance(walletIds: [Wallet.personalID, "wallet_side"]) == 1_500)
        let adjustments = try context.fetch(FetchDescriptor<BalanceAdjustment>())
        #expect(adjustments.count == 2)
        #expect(adjustments.first { $0.walletId == Wallet.personalID }?.amount == 100)
        #expect(adjustments.first { $0.walletId == "wallet_side" }?.amount == -100)
    }

    @Test("A pre-anchor wallet move remains correct after closing and reopening the store")
    func movingPreAnchorExpensePersistsAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickSpendTransaction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("QuickSpend.sqlite")
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)

        func seedAndClose() throws {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = container.mainContext
            context.insert(BalanceAnchor(walletId: Wallet.personalID, openingBalance: 1_000, anchorDate: anchorDate))
            context.insert(BalanceAnchor(walletId: "wallet_side", openingBalance: 500, anchorDate: anchorDate))
            context.insert(Transaction(
                id: "tx_durable", amount: 100, note: "Old", categoryId: "food",
                walletId: Wallet.personalID, type: .expense,
                createdAt: anchorDate.addingTimeInterval(-60)
            ))
            try context.save()
        }

        func updateAndClose() throws {
            let container = try makeOnDiskContainer(at: storeURL)
            let context = container.mainContext
            let transaction = try #require(context.fetch(FetchDescriptor<Transaction>()).first)
            let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
            let updated = Transaction(
                id: transaction.id, amount: 100, note: transaction.note,
                categoryId: transaction.categoryId, walletId: "wallet_side",
                type: .expense, date: transaction.date
            )
            try TransactionPersistence.update(
                transaction, with: updated, modelContext: context, balanceService: balance
            )
        }

        try seedAndClose()
        try updateAndClose()

        let reopened = try makeOnDiskContainer(at: storeURL)
        let context = reopened.mainContext
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.walletId == "wallet_side")
        #expect(try context.fetchCount(FetchDescriptor<BalanceAdjustment>()) == 2)
        #expect(try balance.computeBalance(walletId: Wallet.personalID) == 1_100)
        #expect(try balance.computeBalance(walletId: "wallet_side") == 400)
    }

    @Test("Moving a post-anchor expense relies on transaction history without redundant adjustments")
    func movingPostAnchorExpenseNeedsNoAdjustment() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            id: "tx_post_anchor",
            amount: 100,
            note: "Recent expense",
            categoryId: "food",
            walletId: Wallet.personalID,
            type: .expense,
            createdAt: anchorDate.addingTimeInterval(60)
        )
        context.insert(BalanceAnchor(walletId: Wallet.personalID, openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(BalanceAnchor(walletId: "wallet_side", openingBalance: 500, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        let updated = Transaction(
            id: transaction.id,
            amount: 100,
            note: transaction.note,
            categoryId: transaction.categoryId,
            walletId: "wallet_side",
            type: .expense,
            date: transaction.date
        )

        try TransactionPersistence.update(
            transaction,
            with: updated,
            modelContext: context,
            balanceService: balance
        )

        #expect(try balance.computeBalance(walletId: Wallet.personalID) == 1_000)
        #expect(try balance.computeBalance(walletId: "wallet_side") == 400)
        #expect(try context.fetchCount(FetchDescriptor<BalanceAdjustment>()) == 0)
    }

    @Test("Editing the amount of a pre-anchor expense applies the exact signed delta")
    func editingPreAnchorAmountAppliesDelta() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            amount: 100, note: "Old", categoryId: "food", type: .expense,
            createdAt: anchorDate.addingTimeInterval(-60)
        )
        context.insert(BalanceAnchor(openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        let updated = Transaction(
            id: transaction.id, amount: 250, note: "Old", categoryId: "food",
            type: .expense, date: transaction.date
        )

        try TransactionPersistence.update(
            transaction, with: updated, modelContext: context, balanceService: balance
        )

        #expect(try balance.computeBalance() == 850)
        #expect(try context.fetch(FetchDescriptor<BalanceAdjustment>()).first?.amount == -150)
    }

    @Test("Deleting a pre-anchor expense restores its contribution")
    func deletingPreAnchorExpenseRestoresContribution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            amount: 100, note: "Old", categoryId: "food", type: .expense,
            createdAt: anchorDate.addingTimeInterval(-60)
        )
        context.insert(BalanceAnchor(openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        try TransactionPersistence.delete(
            transaction, modelContext: context, balanceService: balance
        )

        #expect(try balance.computeBalance() == 1_100)
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(try context.fetch(FetchDescriptor<BalanceAdjustment>()).first?.amount == 100)
    }

    @Test("A failed wallet move restores the transaction and creates no adjustment")
    func failedMoveRestoresTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            id: "tx_failed", amount: 100, note: "Old", categoryId: "food",
            walletId: Wallet.personalID, type: .expense,
            createdAt: anchorDate.addingTimeInterval(-60)
        )
        context.insert(BalanceAnchor(walletId: Wallet.personalID, openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(BalanceAnchor(walletId: "wallet_side", openingBalance: 500, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        let updated = Transaction(
            id: transaction.id, amount: 200, note: "Changed", categoryId: "tools",
            walletId: "wallet_side", type: .income, date: transaction.date
        )

        #expect(throws: InjectedFailure.self) {
            try TransactionPersistence.update(
                transaction,
                with: updated,
                modelContext: context,
                balanceService: balance,
                save: { _ in throw InjectedFailure.save }
            )
        }

        #expect(transaction.amount == 100)
        #expect(transaction.note == "Old")
        #expect(transaction.categoryId == "food")
        #expect(transaction.walletId == Wallet.personalID)
        #expect(transaction.type == .expense)
        #expect(try context.fetchCount(FetchDescriptor<BalanceAdjustment>()) == 0)
        #expect(balance.currentBalance == 1_000)
        #expect(balance.currentBalance(for: "wallet_side") == 500)
    }

    @Test("A failed delete restores the transaction and balance")
    func failedDeleteRestoresTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transaction = Transaction(
            id: "tx_failed_delete", amount: 100, note: "Old", categoryId: "food",
            type: .expense, createdAt: anchorDate.addingTimeInterval(-60)
        )
        context.insert(BalanceAnchor(openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(transaction)
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)

        #expect(throws: InjectedFailure.self) {
            try TransactionPersistence.delete(
                transaction,
                modelContext: context,
                balanceService: balance,
                save: { _ in throw InjectedFailure.save }
            )
        }

        #expect(try context.fetch(FetchDescriptor<Transaction>()).map(\.id) == ["tx_failed_delete"])
        #expect(try context.fetchCount(FetchDescriptor<BalanceAdjustment>()) == 0)
        #expect(balance.currentBalance == 1_000)
    }
}

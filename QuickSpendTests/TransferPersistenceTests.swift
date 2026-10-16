import Foundation
import SwiftData
import Testing
@testable import QuickSpend

@Suite("Transfer Persistence Tests")
@MainActor
struct TransferPersistenceTests {
    private enum InjectedFailure: Error { case save }

    private let cash = "wallet_cash_test"
    private let bank = "wallet_bank_test"
    private let savings = "wallet_savings_test"
    private let anchorDate = Date(timeIntervalSince1970: 1_700_000_000)

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let balance: BalanceService
    }

    /// Three wallets anchored at 1,000 / 500 / 0 with no transactions.
    private func makeFixture() throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: configuration
        )
        let context = container.mainContext
        context.insert(BalanceAnchor(walletId: cash, openingBalance: 1_000, anchorDate: anchorDate))
        context.insert(BalanceAnchor(walletId: bank, openingBalance: 500, anchorDate: anchorDate))
        context.insert(BalanceAnchor(walletId: savings, openingBalance: 0, anchorDate: anchorDate))
        try context.save()
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        return Fixture(container: container, context: context, balance: balance)
    }

    private func makeTransfer(from: String, to: String, amount: Double) -> Transfer {
        Transfer(
            id: "tr_test",
            fromWalletId: from,
            toWalletId: to,
            amount: amount,
            date: anchorDate.addingTimeInterval(3_600),
            note: "Test transfer"
        )
    }

    private func balances(_ fixture: Fixture) throws -> (cash: Double?, bank: Double?, savings: Double?) {
        (
            try fixture.balance.computeBalance(walletId: cash),
            try fixture.balance.computeBalance(walletId: bank),
            try fixture.balance.computeBalance(walletId: savings)
        )
    }

    // MARK: - Create

    @Test("Creating a transfer moves money between wallets and keeps the total")
    func testCreateMovesMoney() throws {
        let fixture = try makeFixture()

        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 800)
        #expect(result.bank == 700)
        #expect(try fixture.balance.computeTotalBalance(walletIds: [cash, bank, savings]) == 1_500)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Transaction>()) == 2)
    }

    @Test("Creating an invalid transfer throws and saves nothing")
    func testCreateRejectsSameWallet() throws {
        let fixture = try makeFixture()

        #expect(throws: TransferPersistence.TransferError.invalidTransfer) {
            try TransferPersistence.create(
                makeTransfer(from: cash, to: cash, amount: 200),
                modelContext: fixture.context,
                balanceService: fixture.balance
            )
        }
        #expect(try fixture.context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test("A failed save rolls back both legs and both balances")
    func testCreateRollsBackOnFailure() throws {
        let fixture = try makeFixture()

        #expect(throws: InjectedFailure.save) {
            try TransferPersistence.create(
                makeTransfer(from: cash, to: bank, amount: 200),
                modelContext: fixture.context,
                balanceService: fixture.balance,
                save: { _ in throw InjectedFailure.save }
            )
        }

        #expect(try fixture.context.fetchCount(FetchDescriptor<Transaction>()) == 0)
        #expect(fixture.balance.currentBalance(for: cash) == 1_000)
        #expect(fixture.balance.currentBalance(for: bank) == 500)
    }

    // MARK: - Lookup

    @Test("Both legs can be found from the transfer id")
    func testLegsLookup() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)

        #expect(legs.count == 2)
        #expect(Set(legs.map(\.walletId)) == [cash, bank])
    }

    // MARK: - Update

    @Test("Editing the amount updates both wallets")
    func testUpdateAmount() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )
        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)

        try TransferPersistence.update(
            legs: legs,
            to: makeTransfer(from: cash, to: bank, amount: 300),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 700)
        #expect(result.bank == 800)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Transaction>()) == 2)
    }

    @Test("Changing the destination wallet moves the incoming leg")
    func testUpdateDestination() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )
        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)

        try TransferPersistence.update(
            legs: legs,
            to: makeTransfer(from: cash, to: savings, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 800)
        #expect(result.bank == 500)
        #expect(result.savings == 200)
    }

    @Test("Editing keeps the legs' original creation date")
    func testUpdatePreservesCreatedAt() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )
        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)
        let originalCreatedAt = legs[0].createdAt

        try TransferPersistence.update(
            legs: legs,
            to: makeTransfer(from: cash, to: bank, amount: 300),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let updated = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)
        #expect(updated.allSatisfy { $0.createdAt == originalCreatedAt })
    }

    @Test("Editing a transfer whose incoming leg is missing recreates it")
    func testUpdateRepairsMissingLeg() throws {
        let fixture = try makeFixture()
        let transfer = makeTransfer(from: cash, to: bank, amount: 200)
        let out = transfer.makeLegs()[0]
        try TransactionPersistence.create(out, modelContext: fixture.context, balanceService: fixture.balance)

        try TransferPersistence.update(
            legs: [out],
            to: transfer,
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 800)
        #expect(result.bank == 700)
        #expect(try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context).count == 2)
    }

    @Test("A failed edit restores the original legs and balances")
    func testUpdateRollsBackOnFailure() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )
        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)

        #expect(throws: InjectedFailure.save) {
            try TransferPersistence.update(
                legs: legs,
                to: makeTransfer(from: cash, to: savings, amount: 999),
                modelContext: fixture.context,
                balanceService: fixture.balance,
                save: { _ in throw InjectedFailure.save }
            )
        }

        let restored = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)
        #expect(restored.count == 2)
        #expect(restored.allSatisfy { $0.amount == 200 })
        #expect(Set(restored.map(\.walletId)) == [cash, bank])
        #expect(fixture.balance.currentBalance(for: cash) == 800)
        #expect(fixture.balance.currentBalance(for: bank) == 700)
    }

    // MARK: - Delete

    @Test("Deleting a transfer removes both legs and restores both balances")
    func testDelete() throws {
        let fixture = try makeFixture()
        try TransferPersistence.create(
            makeTransfer(from: cash, to: bank, amount: 200),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )
        let legs = try TransferPersistence.legs(transferId: "tr_test", modelContext: fixture.context)

        try TransferPersistence.delete(
            legs: legs,
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 1_000)
        #expect(result.bank == 500)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    // MARK: - Pre-anchor history

    @Test("Deleting a transfer recorded before a balance confirmation keeps confirmed balances exact")
    func testDeletePreAnchorTransfer() throws {
        let fixture = try makeFixture()
        var transfer = makeTransfer(from: cash, to: bank, amount: 200)
        transfer.date = anchorDate.addingTimeInterval(-3_600)
        // Legs created before the anchor are already reflected in the opening balances.
        let legs = transfer.makeLegs(createdAt: anchorDate.addingTimeInterval(-60))
        legs.forEach(fixture.context.insert)
        try fixture.context.save()

        try TransferPersistence.delete(
            legs: legs,
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        let result = try balances(fixture)
        #expect(result.cash == 1_200)
        #expect(result.bank == 300)
        #expect(try fixture.balance.computeTotalBalance(walletIds: [cash, bank, savings]) == 1_500)
    }

    // MARK: - Regression: transfer into a wallet without a starting balance

    @Test("Transferring into a wallet with no starting balance gives it that balance and keeps the total")
    func testTransferIntoUnanchoredWalletKeepsTotal() throws {
        let fixture = try makeFixture()
        let newWallet = "wallet_new_test"
        #expect(try fixture.balance.computeBalance(walletId: newWallet) == nil)

        try TransferPersistence.create(
            makeTransfer(from: cash, to: newWallet, amount: 2_005),
            modelContext: fixture.context,
            balanceService: fixture.balance
        )

        #expect(try fixture.balance.computeBalance(walletId: cash) == -1_005)
        #expect(try fixture.balance.computeBalance(walletId: newWallet) == 2_005)
        #expect(fixture.balance.currentBalance(for: newWallet) == 2_005)
        #expect(try fixture.balance.computeTotalBalance(walletIds: [cash, bank, savings, newWallet]) == 1_500)
    }
}

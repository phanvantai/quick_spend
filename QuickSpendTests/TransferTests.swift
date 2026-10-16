import Foundation
import Testing
@testable import QuickSpend

@Suite("Transfer Tests")
struct TransferTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_900_000_000)

    private func makeTransfer(id: String = "tr_test") -> Transfer {
        Transfer(
            id: id,
            fromWalletId: "wallet_cash_test",
            toWalletId: "wallet_bank_test",
            amount: 250,
            date: fixedDate,
            note: "Move test funds"
        )
    }

    // MARK: - Legs

    @Test("A transfer becomes an outgoing expense leg and an incoming income leg")
    func testMakeLegs() {
        let legs = makeTransfer().makeLegs()

        #expect(legs.count == 2)
        let out = legs[0]
        let incoming = legs[1]
        #expect(out.id == "transfer:tr_test:out")
        #expect(out.walletId == "wallet_cash_test")
        #expect(out.type == .expense)
        #expect(incoming.id == "transfer:tr_test:in")
        #expect(incoming.walletId == "wallet_bank_test")
        #expect(incoming.type == .income)
        for leg in legs {
            #expect(leg.amount == 250)
            #expect(leg.categoryId == Transfer.categoryId)
            #expect(leg.date == fixedDate)
            #expect(leg.note == "Move test funds")
            #expect(leg.isTransfer)
        }
    }

    @Test("Legs expose their transfer id, side, and counterpart")
    func testLegIdentity() {
        let legs = makeTransfer().makeLegs()

        #expect(legs[0].transferId == "tr_test")
        #expect(legs[0].transferLeg == .outgoing)
        #expect(legs[0].transferCounterpartId == "transfer:tr_test:in")
        #expect(legs[1].transferLeg == .incoming)
        #expect(legs[1].transferCounterpartId == "transfer:tr_test:out")
    }

    @Test("Regular transactions are not transfers")
    func testRegularTransactionIsNotTransfer() {
        let tx = Transaction(amount: 10, note: "Coffee", categoryId: "food_drink")

        #expect(!tx.isTransfer)
        #expect(tx.transferId == nil)
        #expect(tx.transferLeg == nil)
        #expect(tx.transferCounterpartId == nil)
    }

    @Test("A user category named 'transfer' does not collide with the transfer marker")
    func testUserCategoryIdDoesNotCollide() {
        let tx = Transaction(amount: 10, note: "Manual", categoryId: "transfer")
        #expect(!tx.isTransfer)
    }

    // MARK: - Rebuilding

    @Test("A transfer can be rebuilt from its two legs in any order")
    func testRebuildFromLegs() {
        let original = makeTransfer()
        let legs = original.makeLegs()

        #expect(Transfer(legs: legs) == original)
        #expect(Transfer(legs: legs.reversed()) == original)
    }

    @Test("Rebuilding from a single outgoing leg keeps the source wallet")
    func testRebuildFromOutgoingLegOnly() {
        let out = makeTransfer().makeLegs()[0]

        let rebuilt = Transfer(legs: [out])

        #expect(rebuilt?.id == "tr_test")
        #expect(rebuilt?.fromWalletId == "wallet_cash_test")
        #expect(rebuilt?.amount == 250)
    }

    @Test("Non-transfer transactions cannot be rebuilt into a transfer")
    func testRebuildRejectsRegularTransactions() {
        let tx = Transaction(amount: 10, note: "Coffee", categoryId: "food_drink")
        #expect(Transfer(legs: [tx]) == nil)
        #expect(Transfer(legs: []) == nil)
    }

    // MARK: - Validation

    @Test("A transfer needs a positive amount and two different wallets")
    func testValidation() {
        var transfer = makeTransfer()
        #expect(transfer.isValid)

        transfer.toWalletId = transfer.fromWalletId
        #expect(!transfer.isValid)

        transfer = makeTransfer()
        transfer.amount = 0
        #expect(!transfer.isValid)
    }

    // MARK: - Stats exclusion

    @Test("excludingTransfers keeps only real income and expenses")
    func testExcludingTransfers() {
        let coffee = Transaction(amount: 10, note: "Coffee", categoryId: "food_drink")
        let all = [coffee] + makeTransfer().makeLegs()

        let filtered = all.excludingTransfers()

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == coffee.id)
    }
}

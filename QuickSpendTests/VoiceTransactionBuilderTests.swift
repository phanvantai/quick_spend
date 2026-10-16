import Foundation
import Testing
@testable import QuickSpend

@Suite("VoiceTransactionBuilder Tests")
struct VoiceTransactionBuilderTests {

    private let date = Date(timeIntervalSince1970: 1_900_000_000)

    private func expense(walletId: String? = nil) -> ParsedTransaction {
        var parsed = ParsedTransaction(
            amount: 40, note: "Lunch test", categoryId: "food_drink",
            type: .expense, date: date, confidence: 0.95, rawInput: "lunch 40"
        )
        parsed.walletId = walletId
        return parsed
    }

    private func transfer(from: String?, to: String) -> ParsedTransaction {
        var parsed = ParsedTransaction(
            amount: 500, note: "Savings test", categoryId: Transfer.categoryId,
            type: .expense, date: date, confidence: 0.95, rawInput: "move 500"
        )
        parsed.walletId = from
        parsed.transferToWalletId = to
        return parsed
    }

    @Test("A regular item becomes one transaction in its wallet")
    func testRegularItem() throws {
        let transactions = try VoiceTransactionBuilder.transactions(
            from: [expense(walletId: "wallet_bank_test")], defaultWalletId: "wallet_default_test"
        )
        #expect(transactions.count == 1)
        #expect(transactions[0].walletId == "wallet_bank_test")
        #expect(transactions[0].rawInput == "lunch 40")
        #expect(transactions[0].confidence == 0.95)
        #expect(!transactions[0].isTransfer)
    }

    @Test("An item without a wallet goes to the default wallet")
    func testDefaultWallet() throws {
        let transactions = try VoiceTransactionBuilder.transactions(from: [expense()], defaultWalletId: "wallet_default_test")
        #expect(transactions[0].walletId == "wallet_default_test")
    }

    @Test("A transfer becomes two legs that net to zero")
    func testTransferLegs() throws {
        let transactions = try VoiceTransactionBuilder.transactions(
            from: [transfer(from: "wallet_cash_test", to: "wallet_bank_test")], defaultWalletId: "wallet_default_test"
        )
        #expect(transactions.count == 2)
        #expect(transactions.allSatisfy { $0.isTransfer })
        #expect(transactions.first { $0.transferLeg == .outgoing }?.walletId == "wallet_cash_test")
        #expect(transactions.first { $0.transferLeg == .incoming }?.walletId == "wallet_bank_test")
        let net = transactions.reduce(0.0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        #expect(net == 0)
    }

    @Test("A transfer without a source leaves from the default wallet")
    func testTransferDefaultSource() throws {
        let transactions = try VoiceTransactionBuilder.transactions(
            from: [transfer(from: nil, to: "wallet_bank_test")], defaultWalletId: "wallet_default_test"
        )
        #expect(transactions.first { $0.transferLeg == .outgoing }?.walletId == "wallet_default_test")
    }

    @Test("An incomplete transfer cannot be saved")
    func testIncompleteTransferThrows() {
        #expect(throws: VoiceTransactionBuilder.BuildError.incompleteTransfer) {
            try VoiceTransactionBuilder.transactions(
                from: [expense(), transfer(from: "wallet_bank_test", to: "")], defaultWalletId: "wallet_default_test"
            )
        }
        #expect(throws: VoiceTransactionBuilder.BuildError.incompleteTransfer) {
            try VoiceTransactionBuilder.transactions(
                from: [transfer(from: "wallet_bank_test", to: "wallet_bank_test")], defaultWalletId: "wallet_default_test"
            )
        }
    }
}

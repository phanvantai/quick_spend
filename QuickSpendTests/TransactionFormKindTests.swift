import Testing
@testable import QuickSpend

@Suite("TransactionFormKind Tests")
struct TransactionFormKindTests {

    @Test("Adding with two or more wallets offers expense, income, and transfer")
    func testAddingWithManyWallets() {
        let kinds = TransactionFormKind.available(editing: nil, canTransfer: true, activeWalletCount: 2)
        #expect(kinds == [.expense, .income, .transfer])
    }

    @Test("Transfer is hidden with a single wallet")
    func testSingleWalletHidesTransfer() {
        let kinds = TransactionFormKind.available(editing: nil, canTransfer: true, activeWalletCount: 1)
        #expect(kinds == [.expense, .income])
    }

    @Test("Transfer is hidden when the caller cannot save transfers")
    func testNoTransferHandlerHidesTransfer() {
        let kinds = TransactionFormKind.available(editing: nil, canTransfer: false, activeWalletCount: 3)
        #expect(kinds == [.expense, .income])
    }

    @Test("Editing a transaction can switch between expense and income only")
    func testEditingTransaction() {
        let kinds = TransactionFormKind.available(editing: .expense, canTransfer: true, activeWalletCount: 3)
        #expect(kinds == [.expense, .income])
    }

    @Test("Editing a transfer stays a transfer")
    func testEditingTransfer() {
        let kinds = TransactionFormKind.available(editing: .transfer, canTransfer: true, activeWalletCount: 3)
        #expect(kinds == [.transfer])
    }

    @Test("Kinds map to transaction types")
    func testTransactionTypeMapping() {
        #expect(TransactionFormKind(.expense) == .expense)
        #expect(TransactionFormKind(.income) == .income)
        #expect(TransactionFormKind.expense.transactionType == .expense)
        #expect(TransactionFormKind.income.transactionType == .income)
        #expect(TransactionFormKind.transfer.transactionType == nil)
    }

    @Test("Transfer strings are translated in every language")
    func testTransferStringsLocalized() {
        let keys = [
            "transfer.title", "transfer.edit_title", "transfer.from", "transfer.to",
            "transfer.choose_wallet", "transfer.to_wallet", "transfer.from_wallet",
            "transfer.same_wallet_error", "transfer.delete_confirm", "transfer.not_counted",
        ]
        for language in ["en", "vi", "ja", "es"] {
            for key in keys {
                #expect(L10n.tr(key, language) != key, "\(key) missing for \(language)")
            }
        }
        #expect(L10n.tr("transfer.to_wallet", "vi", "Ngân hàng") == "Chuyển đến Ngân hàng")
    }
}

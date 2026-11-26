import Testing
import Foundation
@testable import QuickSpend

@Suite("BankAlertInbox Tests")
struct BankAlertInboxTests {

    private let inbox: BankAlertInbox
    private let defaults: UserDefaults

    init() {
        let suite = "BankAlertInboxTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        inbox = BankAlertInbox(defaults: defaults)
    }

    private func item(_ id: String, amount: Double = 10_000, type: TransactionType = .expense, date: Date = Date(timeIntervalSince1970: 1_000_000)) -> PendingBankAlert {
        PendingBankAlert(
            id: id, bankId: "vcb", type: type, amount: amount, date: date, note: "Test note",
            categoryId: "other_expense", walletId: Wallet.personalID, receivedAt: date
        )
    }

    @Test("Items persist across instances, newest first")
    func persistsNewestFirst() {
        inbox.add(item("a"))
        inbox.add(item("b"))
        let reopened = BankAlertInbox(defaults: defaults)
        #expect(reopened.items.map(\.id) == ["b", "a"])
        #expect(reopened.count == 2)
    }

    @Test("Adding an id again replaces the old item")
    func addReplaces() {
        inbox.add(item("a", amount: 1))
        inbox.add(item("a", amount: 2))
        #expect(inbox.items.map(\.amount) == [2])
    }

    @Test("Remove and removeAll")
    func removing() {
        inbox.add(item("a"))
        inbox.add(item("b"))
        inbox.remove(id: "a")
        #expect(inbox.items.map(\.id) == ["b"])
        inbox.removeAll()
        #expect(inbox.items.isEmpty)
    }

    @Test("The list keeps at most `capacity` items")
    func capacity() {
        for i in 0..<(BankAlertInbox.capacity + 5) { inbox.add(item("i\(i)")) }
        #expect(inbox.count == BankAlertInbox.capacity)
        #expect(inbox.items.first?.id == "i\(BankAlertInbox.capacity + 4)")
    }

    @Test("Matches by id, or by signed amount within the window")
    func matching() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        inbox.add(item("a", amount: 50_000, type: .expense, date: date))
        #expect(inbox.containsMatch(id: "a", signedAmount: 1, date: .distantPast, window: 60))
        #expect(inbox.containsMatch(id: "x", signedAmount: -50_000, date: date.addingTimeInterval(59), window: 60))
        #expect(!inbox.containsMatch(id: "x", signedAmount: -50_000, date: date.addingTimeInterval(61), window: 60))
        #expect(!inbox.containsMatch(id: "x", signedAmount: 50_000, date: date, window: 60))
    }

    @Test("Changes are announced so open screens refresh")
    func postsNotification() async {
        await confirmation { changed in
            let token = NotificationCenter.default.addObserver(forName: .bankAlertInboxDidChange, object: nil, queue: nil) { _ in
                changed()
            }
            inbox.add(item("a"))
            NotificationCenter.default.removeObserver(token)
        }
    }

    @Test("Pending items become transactions with no raw input")
    func makeTransaction() {
        let t = item("bankalert:vcb:1:-10000").makeTransaction()
        #expect(t.id == "bankalert:vcb:1:-10000")
        #expect(t.rawInput == nil)
        #expect(t.amount == 10_000)
    }
}

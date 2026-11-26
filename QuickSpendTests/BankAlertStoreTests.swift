import Testing
import Foundation
import SwiftData
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@Suite("BankAlertStore Tests")
@MainActor
struct BankAlertStoreTests {

    private let defaults: UserDefaults
    private let preferences: PreferencesService
    private let inbox: BankAlertInbox
    private let container: ModelContainer

    init() throws {
        defaults = UserDefaults(suiteName: "BankAlertStoreTests-\(UUID().uuidString)")!
        preferences = PreferencesService(defaults: defaults)
        inbox = BankAlertInbox(defaults: defaults)
        container = try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func item(_ id: String) -> PendingBankAlert {
        PendingBankAlert(
            id: id, bankId: "tpbank", type: .expense, amount: 12_000, date: Date(timeIntervalSince1970: 1_000_000),
            note: "Test note", categoryId: "other_expense", walletId: Wallet.personalID,
            receivedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    private func makeStore(templates: BankAlertTemplateStore? = nil) -> BankAlertStore {
        BankAlertStore(
            inbox: inbox,
            preferences: preferences,
            templates: templates ?? BankAlertTemplateStore(defaults: defaults),
            rules: BankAlertCategoryRules(defaults: defaults),
            uncategorized: UncategorizedBankTransactions(defaults: defaults)
        )
    }

    private var balanceService: BalanceService {
        BalanceService(modelContext: container.mainContext, autoObserve: false, autoCompute: false)
    }

    @Test("Settings changes are saved to preferences")
    func settingsPersist() {
        let store = makeStore()
        #expect(store.isEnabled)

        store.setEnabled(false)
        store.setAlwaysReview(true)
        store.setWalletId("wallet-a", forBank: "vcb")

        #expect(preferences.bankAlertsEnabled == false)
        #expect(preferences.bankAlertsAlwaysReview == true)
        #expect(store.walletIds == ["vcb": "wallet-a"])

        store.setWalletId(nil, forBank: "vcb")
        #expect(store.walletIds.isEmpty)
    }

    @Test("Items added to the inbox elsewhere show up in the store")
    func reloadsOnInboxChange() {
        let store = makeStore()
        #expect(store.pending.isEmpty)

        inbox.add(item("a"))

        #expect(store.pending.map(\.id) == ["a"])
    }

    @Test("Approve all saves every item and empties the list")
    func approveAll() throws {
        inbox.add(item("bankalert:x:1"))
        inbox.add(item("bankalert:x:2"))
        let store = makeStore()

        try store.approveAll(in: container.mainContext, balanceService: balanceService)

        #expect(store.pending.isEmpty)
        let ids = try container.mainContext.fetch(FetchDescriptor<Transaction>()).map(\.id).sorted()
        #expect(ids == ["bankalert:x:1", "bankalert:x:2"])
    }

    @Test("Discard and discard all")
    func discarding() {
        inbox.add(item("a"))
        inbox.add(item("b"))
        let store = makeStore()

        store.discard(store.pending[0])
        #expect(store.pending.map(\.id) == ["a"])

        store.discardAll()
        #expect(store.pending.isEmpty)
        #expect(inbox.items.isEmpty)
    }

    @Test("Only Vietcombank app notifications are read with full support")
    func channelSupport() {
        #expect(BankAlertChannel.notification.vietcombankSupport == .full)
        #expect(BankAlertChannel.sms.vietcombankSupport == .beta)
        #expect(BankAlertChannel.email.vietcombankSupport == .beta)
    }

    @Test("Deleting a learned format also forgets its wallet")
    func deleteTemplate() throws {
        let templates = BankAlertTemplateStore(defaults: defaults)
        let store = makeStore(templates: templates)
        let template = BankAlertTemplate(
            id: "tpl", bankName: "Test Bank", pattern: "test", typeRule: .fromSign,
            preview: "test", createdAt: Date(timeIntervalSince1970: 0)
        )
        store.addTemplate(template)
        store.setWalletId("wallet-a", forBank: "tpl")
        #expect(store.templates.map(\.id) == ["tpl"])

        store.deleteTemplate(template)

        #expect(store.templates.isEmpty)
        #expect(store.walletIds["tpl"] == nil)
    }

    @Test("The notification trigger needs iOS 27; SMS and email work on the app's minimum")
    func channelAvailability() {
        #expect(!BankAlertChannel.notification.isAvailable(onMajorVersion: 26))
        #expect(BankAlertChannel.notification.isAvailable(onMajorVersion: 27))
        #expect(BankAlertChannel.sms.isAvailable(onMajorVersion: 18))
        #expect(BankAlertChannel.email.isAvailable(onMajorVersion: 18))
    }
}

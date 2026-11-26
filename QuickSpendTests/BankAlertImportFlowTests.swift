import Testing
import Foundation
import SwiftData
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

/// Fixtures are made up: no real account numbers, names or references.
@Suite("BankAlertImportFlow Tests")
@MainActor
struct BankAlertImportFlowTests {

    private let alertText = "Số dư TK VCB 0123456789 -25,000 VND lúc 21-11-2026 08:39:57. Số dư 1,234,567 VND. Ref MBVCB.11111111111.ABC123DEF.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi 9876543210 TRAN THI B tai TPBANK"

    private let laterAlertSameRecipient = "Số dư TK VCB 0123456789 -30,000 VND lúc 22-11-2026 09:00:00. Số dư 1,204,567 VND. Ref MBVCB.44444444444.ZZZ.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi 9876543210 TRAN THI B tai TPBANK"

    /// Same money movement as `alertText`, as a (made-up) SMS a minute later.
    private let sameMovementBySMS = "VCB: TK 0123456789 GD: -25,000VND 21/11/2026 08:40. SD: 1,234,567VND. ND: chuyen tien"

    /// A Vietcombank SMS-style alert read by the generic parser, made up.
    private let genericAlert = "VCB: TK 0000111122 GD: -120,000VND 21/11/2026 10:15 SD: 900,000VND ND: thanh toan dien thoai"

    /// Another bank's alert, made up.
    private let otherBankAlert = "TPBank: TK 0000111122 GD: -80,000VND 21/11/2026 11:00 SD: 820,000VND ND: an trua"

    private let container: ModelContainer
    private let context: ModelContext
    private let inbox: BankAlertInbox

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: config
        )
        context = container.mainContext
        let suite = "BankAlertImportFlowTests-\(UUID().uuidString)"
        inbox = BankAlertInbox(defaults: UserDefaults(suiteName: suite)!)
    }

    /// Fixed "now" near the fixtures' dates, so the generic parser trusts them.
    private let now = Date(timeIntervalSince1970: 1_795_740_000) // 2026-11-27 (UTC)

    private func importAlert(
        _ text: String,
        settings: BankAlertSettings = BankAlertSettings(),
        categorizer: BankAlertCategorizer? = nil
    ) async throws -> BankAlertImportResult {
        try await BankAlertImportFlow.importAlert(
            text: text, settings: settings, in: context, inbox: inbox, categorizer: categorizer, now: now
        )
    }

    /// A Premium categorizer with no AI and its own empty rules.
    private func premiumCategorizer() -> BankAlertCategorizer {
        BankAlertCategorizer(
            isPremium: true, useAI: false,
            rules: BankAlertCategoryRules(defaults: UserDefaults(suiteName: "rules-\(UUID().uuidString)")!),
            ai: nil
        )
    }

    private func storedTransactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    // MARK: - Saving verified alerts

    @Test("A Vietcombank alert is saved as one transaction with the parsed fields")
    func savesTransaction() async throws {
        var settings = BankAlertSettings()
        settings.defaultWalletId = "wallet-test"

        let result = try await importAlert(alertText, settings: settings)

        guard case .saved(let saved) = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        let stored = try storedTransactions()
        #expect(stored.count == 1)
        #expect(stored[0].id == saved.id)
        #expect(saved.id == "bankalert:vcb:20261121083957:-25000")
        #expect(saved.amount == 25_000)
        #expect(saved.type == .expense)
        #expect(saved.note == "Tran Thi B (TPBANK)")
        #expect(saved.categoryId == "other_expense")
        #expect(saved.walletId == "wallet-test")
        #expect(saved.confidence == 1.0)
        #expect(inbox.items.isEmpty)
    }

    @Test("The raw alert (account number, balance) is never stored")
    func rawAlertNotStored() async throws {
        _ = try await importAlert(alertText)

        let stored = try #require(try storedTransactions().first)
        #expect(stored.rawInput == nil)
        #expect(!stored.note.contains("0123456789"))
        #expect(!stored.note.contains("1,234,567"))
    }

    // MARK: - Duplicates

    @Test("The same alert arriving twice is recorded once")
    func duplicateIsSkipped() async throws {
        _ = try await importAlert(alertText)
        let second = try await importAlert("Vietcombank\n" + alertText)

        #expect(second == .duplicate)
        #expect(try storedTransactions().count == 1)
    }

    @Test("The same movement by SMS a minute after the notification is a duplicate")
    func crossChannelDuplicate() async throws {
        _ = try await importAlert(alertText)
        let sms = try await importAlert(sameMovementBySMS)

        #expect(sms == .duplicate)
        #expect(inbox.items.isEmpty)
    }

    @Test("A queued alert arriving again by another channel is not queued twice")
    func duplicateOfQueuedItem() async throws {
        _ = try await importAlert(genericAlert)
        let again = try await importAlert(genericAlert.replacingOccurrences(of: "VCB: ", with: "VCB\n"))

        #expect(again == .duplicate)
        #expect(inbox.items.count == 1)
    }

    // MARK: - Review list

    @Test("A generic alert goes to the review list, not the ledger")
    func genericAlertIsQueued() async throws {
        let result = try await importAlert(genericAlert)

        guard case .queued(let item) = result else {
            Issue.record("Expected .queued, got \(result)")
            return
        }
        #expect(item.amount == 120_000)
        #expect(item.type == .expense)
        #expect(item.bankId == "vcb")
        #expect(try storedTransactions().isEmpty)
        #expect(inbox.items == [item])
    }

    @Test("With 'always review' on, even a Vietcombank alert waits for review")
    func alwaysReviewQueuesVerifiedAlerts() async throws {
        var settings = BankAlertSettings()
        settings.alwaysReview = true

        let result = try await importAlert(alertText, settings: settings)

        guard case .queued = result else {
            Issue.record("Expected .queued, got \(result)")
            return
        }
        #expect(try storedTransactions().isEmpty)
    }

    @Test("Approving a review item saves it under its id and empties the list")
    func approveSavesAndRemoves() async throws {
        guard case .queued(let item) = try await importAlert(genericAlert) else {
            Issue.record("Expected .queued")
            return
        }

        let saved = try BankAlertImportFlow.approve(item, in: context, inbox: inbox)

        #expect(saved.id == item.id)
        #expect(try storedTransactions().map(\.id) == [item.id])
        #expect(inbox.items.isEmpty)
    }

    @Test("Approving with edits keeps the edits but the alert's id, and drops raw input")
    func approveWithEdits() async throws {
        guard case .queued(let item) = try await importAlert(genericAlert) else {
            Issue.record("Expected .queued")
            return
        }
        let edited = Transaction(amount: 99_000, note: "Phone bill", categoryId: "bills_utilities", type: .expense, rawInput: "typed")

        let saved = try BankAlertImportFlow.approve(item, edited: edited, in: context, inbox: inbox)

        #expect(saved.id == item.id)
        #expect(saved.amount == 99_000)
        #expect(saved.categoryId == "bills_utilities")
        #expect(saved.rawInput == nil)
    }

    @Test("Discarding removes the item and saves nothing")
    func discardRemoves() async throws {
        guard case .queued(let item) = try await importAlert(genericAlert) else {
            Issue.record("Expected .queued")
            return
        }

        BankAlertImportFlow.discard(item, inbox: inbox)

        #expect(inbox.items.isEmpty)
        #expect(try storedTransactions().isEmpty)
    }

    // MARK: - Settings

    @Test("Paused bank alerts record nothing")
    func disabledRecordsNothing() async throws {
        var settings = BankAlertSettings()
        settings.isEnabled = false

        #expect(try await importAlert(alertText, settings: settings) == .disabled)
        #expect(try storedTransactions().isEmpty)
        #expect(inbox.items.isEmpty)
    }

    @Test("Text that is not a balance alert saves nothing")
    func unrecognisedSavesNothing() async throws {
        #expect(try await importAlert("Ma OTP cua Quy khach la 123456.") == .unrecognized)
        #expect(try storedTransactions().isEmpty)
    }

    @Test("A non-VND app currency saves nothing, so amounts are never mixed up")
    func otherCurrencySavesNothing() async throws {
        var settings = BankAlertSettings()
        settings.currency = "USD"

        #expect(try await importAlert(alertText, settings: settings) == .unsupportedCurrency)
        #expect(try storedTransactions().isEmpty)
    }

    @Test("A bank mapped to a wallet records into that wallet")
    func bankWalletMapping() async throws {
        var settings = BankAlertSettings()
        settings.walletIds = ["vcb": "wallet-vcb"]
        settings.activeWalletIds = ["wallet-vcb", Wallet.personalID]

        guard case .saved(let saved) = try await importAlert(alertText, settings: settings) else {
            Issue.record("Expected .saved")
            return
        }
        #expect(saved.walletId == "wallet-vcb")
    }

    @Test("A mapping to an archived or deleted wallet falls back to the default wallet")
    func bankWalletMappingToInactiveWallet() async throws {
        var settings = BankAlertSettings()
        settings.walletIds = ["vcb": "wallet-gone"]
        settings.activeWalletIds = [Wallet.personalID]

        guard case .saved(let saved) = try await importAlert(alertText, settings: settings) else {
            Issue.record("Expected .saved")
            return
        }
        #expect(saved.walletId == Wallet.personalID)
    }

    // MARK: - Category learning

    @Test("Premium: a recipient the user re-categorised keeps that category next time")
    func learnsCategoryFromPreviousTransaction() async throws {
        guard case .saved(let first) = try await importAlert(alertText) else {
            Issue.record("Expected first alert to save")
            return
        }
        first.categoryId = "food_drink"
        try context.save()

        let result = try await importAlert(laterAlertSameRecipient, categorizer: premiumCategorizer())

        guard case .saved(let second) = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        #expect(second.categoryId == "food_drink")
    }

    @Test("Free: history isn't used, the transaction stays in Other")
    func freeDoesNotLearn() async throws {
        guard case .saved(let first) = try await importAlert(alertText) else {
            Issue.record("Expected first alert to save")
            return
        }
        first.categoryId = "food_drink"
        try context.save()

        guard case .saved(let second) = try await importAlert(laterAlertSameRecipient) else {
            Issue.record("Expected .saved")
            return
        }
        #expect(second.categoryId == "other_expense")
    }

    @Test("Learning ignores transactions of the other type")
    func learningMatchesTypeOnly() async throws {
        context.insert(Transaction(
            id: "manual-1", amount: 10, note: "Tran Thi B (TPBANK)",
            categoryId: "gift_received", type: .income
        ))
        try context.save()

        guard case .saved(let saved) = try await importAlert(alertText, categorizer: premiumCategorizer()) else {
            Issue.record("Expected .saved")
            return
        }
        #expect(saved.categoryId == "other_expense")
    }

    // MARK: - Vietcombank only and learned formats

    @Test("Another bank's alert is ignored without a learned format")
    func otherBankIgnored() async throws {
        #expect(try await importAlert(otherBankAlert) == .unrecognized)
        #expect(inbox.items.isEmpty)
    }

    @Test("A learned format reads that bank's alerts into review and counts approvals")
    func learnedFormatQueuesAndLearns() async throws {
        let sample = "TPBank: TK 0000111122 GD: -50,000VND 20/11/2026 09:00 SD: 900,000VND ND: cafe"
        let candidate = try #require(BankAlertTemplateBuilder.candidates(in: sample).first { $0.text == "-50,000" })
        let template = try BankAlertTemplateBuilder.build(
            sample: sample, amount: candidate, fixedType: .expense, bankName: "TPBank", now: now, id: "tpl-1"
        )
        let templates = BankAlertTemplateStore(defaults: UserDefaults(suiteName: "tpl-\(UUID().uuidString)")!)
        templates.add(template)
        var settings = BankAlertSettings()
        settings.templates = templates.templates

        guard case .queued(let item) = try await importAlert(otherBankAlert, settings: settings) else {
            Issue.record("Expected .queued")
            return
        }
        #expect(item.templateId == "tpl-1")
        #expect(item.displayBankName == "TPBank")
        #expect(item.amount == 80_000)

        try BankAlertImportFlow.approve(item, in: context, inbox: inbox, templates: templates)
        #expect(templates.templates.first?.approvedCount == 1)
    }

    @Test("Fixing the amount of a learned-format item resets its trust")
    func correctionResetsTrust() async throws {
        let sample = "TPBank: TK 0000111122 GD: -50,000VND 20/11/2026 09:00 SD: 900,000VND ND: cafe"
        let candidate = try #require(BankAlertTemplateBuilder.candidates(in: sample).first { $0.text == "-50,000" })
        var template = try BankAlertTemplateBuilder.build(
            sample: sample, amount: candidate, fixedType: .expense, bankName: "TPBank", now: now, id: "tpl-2"
        )
        template.approvedCount = 2
        let templates = BankAlertTemplateStore(defaults: UserDefaults(suiteName: "tpl-\(UUID().uuidString)")!)
        templates.add(template)
        var settings = BankAlertSettings()
        settings.templates = templates.templates

        guard case .queued(let item) = try await importAlert(otherBankAlert, settings: settings) else {
            Issue.record("Expected .queued")
            return
        }
        let edited = Transaction(amount: 8_000, note: item.note, categoryId: item.categoryId, type: .expense)
        try BankAlertImportFlow.approve(item, edited: edited, in: context, inbox: inbox, templates: templates)

        #expect(templates.templates.first?.approvedCount == 0)
    }

    @Test("A trusted learned format saves straight away")
    func trustedFormatSaves() async throws {
        let sample = "TPBank: TK 0000111122 GD: -50,000VND 20/11/2026 09:00 SD: 900,000VND ND: cafe"
        let candidate = try #require(BankAlertTemplateBuilder.candidates(in: sample).first { $0.text == "-50,000" })
        var template = try BankAlertTemplateBuilder.build(
            sample: sample, amount: candidate, fixedType: .expense, bankName: "TPBank", now: now, id: "tpl-3"
        )
        template.approvedCount = BankAlertTemplate.trustThreshold
        var settings = BankAlertSettings()
        settings.templates = [template]

        guard case .saved(let saved) = try await importAlert(otherBankAlert, settings: settings) else {
            Issue.record("Expected .saved")
            return
        }
        #expect(saved.amount == 80_000)
        #expect(saved.note == "an trua")
    }

    // MARK: - Summary

    @Test("Skipped alerts show nothing; saved and queued ones name the amount and note")
    func summaryText() async throws {
        let config = AppConfig(language: "en", currency: "VND")
        #expect(BankAlertSummary.dialog(for: .duplicate, config: config).isEmpty)
        #expect(BankAlertSummary.dialog(for: .unrecognized, config: config).isEmpty)
        #expect(BankAlertSummary.dialog(for: .disabled, config: config).isEmpty)
        #expect(!BankAlertSummary.dialog(for: .unsupportedCurrency, config: config).isEmpty)

        let saved = Transaction(id: "t", amount: 25_000, note: "Tran Thi B (TPBANK)", categoryId: "other_expense")
        let savedText = BankAlertSummary.dialog(for: .saved(saved), config: config)
        #expect(savedText.contains("Tran Thi B (TPBANK)"))
        #expect(savedText != "bank_alert.saved_expense")

        let queued = PendingBankAlert(
            id: "q", bankId: nil, type: .income, amount: 5_000, date: .now, note: "Test income",
            categoryId: "other_income", walletId: Wallet.personalID, receivedAt: .now
        )
        let queuedText = BankAlertSummary.dialog(for: .queued(queued), config: config)
        #expect(queuedText.contains("Test income"))
        #expect(queuedText != "bank_alert.queued_income")
    }
}

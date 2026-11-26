import Foundation
import Observation
import SwiftData

/// Ways a bank alert can reach QuickSpend through a Shortcuts automation.
enum BankAlertChannel: String, CaseIterable, Identifiable {
    case notification
    case sms
    case email

    var id: String { rawValue }

    /// The Shortcuts trigger exists from this iOS major version.
    var minimumOSVersion: Int {
        switch self {
        case .notification: return 27
        case .sms, .email: return 17
        }
    }

    var iconName: String {
        switch self {
        case .notification: return "app.badge.fill"
        case .sms: return "message.fill"
        case .email: return "envelope.fill"
        }
    }

    /// Guide text keys, `bank_alert.guide.<key>.stepN`. iOS 27 moved
    /// automations into the shortcut editor, so SMS and email have a second set
    /// for it; the notification trigger only exists from iOS 27.
    func guideKey(onMajorVersion major: Int) -> String {
        switch self {
        case .notification: return "notification"
        case .sms: return major >= 27 ? "sms27" : "sms"
        case .email: return major >= 27 ? "email27" : "email"
        }
    }

    func stepCount(onMajorVersion major: Int) -> Int {
        switch guideKey(onMajorVersion: major) {
        case "sms", "email": return 5
        default: return 6
        }
    }

    func isAvailable(onMajorVersion major: Int) -> Bool { major >= minimumOSVersion }

    /// How well Vietcombank alerts are read on this channel: only app
    /// notifications have a parser written against real alerts.
    var vietcombankSupport: BankInfo.Support {
        self == .notification ? .full : .beta
    }
}

/// UI state for the bank-alert settings, review list and Home banner. Reloads
/// whenever the review list changes, including when the Shortcuts action adds
/// an item while the app is open.
@MainActor
@Observable
final class BankAlertStore {
    private(set) var pending: [PendingBankAlert] = []
    private(set) var isEnabled: Bool
    private(set) var alwaysReview: Bool
    private(set) var walletIds: [String: String]
    private(set) var templates: [BankAlertTemplate]
    private(set) var rules: [CategoryRule]
    private(set) var useAI: Bool
    /// Bumped when the dismissed "Uncategorized" ids change, so views refilter.
    private(set) var uncategorizedVersion = 0

    @ObservationIgnored private let inbox: BankAlertInbox
    @ObservationIgnored private let preferences: PreferencesService
    @ObservationIgnored private let templateStore: BankAlertTemplateStore
    @ObservationIgnored private let ruleStore: BankAlertCategoryRules
    @ObservationIgnored private let uncategorized: UncategorizedBankTransactions
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(
        inbox: BankAlertInbox = .shared,
        preferences: PreferencesService = .shared,
        templates: BankAlertTemplateStore = .shared,
        rules: BankAlertCategoryRules = .shared,
        uncategorized: UncategorizedBankTransactions = .shared
    ) {
        self.inbox = inbox
        self.preferences = preferences
        self.templateStore = templates
        self.templates = templates.templates
        self.ruleStore = rules
        self.rules = rules.rules
        self.uncategorized = uncategorized
        useAI = preferences.bankAlertsUseAI
        isEnabled = preferences.bankAlertsEnabled
        alwaysReview = preferences.bankAlertsAlwaysReview
        walletIds = preferences.bankAlertWalletIds
        pending = inbox.items
        observer = NotificationCenter.default.addObserver(
            forName: .bankAlertInboxDidChange, object: nil, queue: nil
        ) { [weak self] _ in
            // Synchronous when posted on the main thread (the intent and the UI
            // both are), so the list is current as soon as `add` returns.
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.reload() }
            } else {
                Task { @MainActor in self?.reload() }
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() {
        pending = inbox.items
        templates = templateStore.templates
        rules = ruleStore.rules
        useAI = preferences.bankAlertsUseAI
        uncategorizedVersion += 1
        isEnabled = preferences.bankAlertsEnabled
        alwaysReview = preferences.bankAlertsAlwaysReview
        walletIds = preferences.bankAlertWalletIds
    }

    func setEnabled(_ value: Bool) {
        preferences.bankAlertsEnabled = value
        isEnabled = value
    }

    func setAlwaysReview(_ value: Bool) {
        preferences.bankAlertsAlwaysReview = value
        alwaysReview = value
    }

    /// nil sends the bank back to the default wallet.
    func setWalletId(_ walletId: String?, forBank bankId: String) {
        preferences.setBankAlertWalletId(walletId, forBank: bankId)
        walletIds = preferences.bankAlertWalletIds
    }

    /// Saves a review item. A Premium user who changed its category gets a
    /// rule, so the same counterparty is categorised that way next time.
    func approve(
        _ item: PendingBankAlert,
        edited: Transaction? = nil,
        isPremium: Bool = false,
        in context: ModelContext,
        balanceService: BalanceService
    ) throws {
        if isPremium, let edited, edited.categoryId != item.categoryId, edited.type == item.type {
            ruleStore.set(note: item.note, type: item.type, categoryId: edited.categoryId)
        }
        try BankAlertImportFlow.approve(item, edited: edited, in: context, inbox: inbox, templates: templateStore, balanceService: balanceService)
        reload()
    }

    /// Saves every item; stops at the first failure, leaving the rest listed.
    func approveAll(in context: ModelContext, balanceService: BalanceService) throws {
        for item in inbox.items.reversed() {
            try BankAlertImportFlow.approve(item, in: context, inbox: inbox, templates: templateStore, balanceService: balanceService)
        }
        reload()
    }

    func discard(_ item: PendingBankAlert) {
        BankAlertImportFlow.discard(item, inbox: inbox)
        pending = inbox.items
    }

    // MARK: - Categorization

    func setUseAI(_ value: Bool) {
        preferences.bankAlertsUseAI = value
        useAI = value
    }

    func deleteRule(_ rule: CategoryRule) {
        ruleStore.remove(id: rule.id)
        rules = ruleStore.rules
    }

    /// Bank-alert transactions still in "other" that the user hasn't kept as is.
    func uncategorizedTransactions(_ all: [Transaction]) -> [Transaction] {
        _ = uncategorizedVersion
        return uncategorized.filter(all)
    }

    /// Sets the category. With `remember` (Premium), also makes a rule and
    /// applies it to the other uncategorized transactions with the same note.
    func assign(
        _ transaction: Transaction,
        categoryId: String,
        remember: Bool,
        among all: [Transaction],
        in context: ModelContext,
        now: Date = .now
    ) throws {
        var targets = [transaction]
        if remember {
            ruleStore.set(note: transaction.note, type: transaction.type, categoryId: categoryId, now: now)
            let key = CategoryRule.key(transaction.note)
            targets += uncategorized.filter(all).filter {
                $0.id != transaction.id && $0.type == transaction.type && CategoryRule.key($0.note) == key
            }
        }
        for target in targets {
            target.categoryId = categoryId
            target.updatedAt = now
        }
        try context.save()
        reload()
    }

    /// "Keep as other": remove it from Uncategorized without changing it.
    func keepAsOther(_ transaction: Transaction) {
        uncategorized.dismiss(id: transaction.id)
        uncategorizedVersion += 1
    }

    // MARK: - Templates

    func addTemplate(_ template: BankAlertTemplate) {
        templateStore.add(template)
        templates = templateStore.templates
    }

    /// Also forgets the template's wallet choice.
    func deleteTemplate(_ template: BankAlertTemplate) {
        templateStore.remove(id: template.id)
        preferences.setBankAlertWalletId(nil, forBank: template.id)
        reload()
    }

    func discardAll() {
        inbox.removeAll()
        pending = []
    }
}

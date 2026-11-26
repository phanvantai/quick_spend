import Testing
import Foundation
import SwiftData
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@MainActor
private final class MockCategorizer: TransactionCategorizing {
    var answer: String?
    var calls: [(note: String, type: TransactionType, allowed: [String])] = []

    init(answer: String?) { self.answer = answer }

    func categoryId(note: String, type: TransactionType, allowedCategoryIds: [String], language: String) async -> String? {
        calls.append((note, type, allowedCategoryIds))
        return answer
    }
}

/// Notes and names are made up.
@Suite("Bank alert categorization Tests")
@MainActor
struct BankAlertCategorizationTests {

    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults
    private let rules: BankAlertCategoryRules

    init() throws {
        container = try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = container.mainContext
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try context.save()
        defaults = UserDefaults(suiteName: "BankAlertCategorizationTests-\(UUID().uuidString)")!
        rules = BankAlertCategoryRules(defaults: defaults)
    }

    private func alert(_ note: String, type: TransactionType = .expense, guess: String? = nil) -> BankAlert {
        BankAlert(
            bank: .vietcombank, type: type, amount: 50_000, date: Date(timeIntervalSince1970: 1_000_000),
            note: note, categoryId: guess ?? BankAlertCategorizer.fallbackCategoryId(for: type),
            isVerified: true, dedupeKey: "vcb:x:-50000"
        )
    }

    private func categorizer(premium: Bool, useAI: Bool = true, ai: TransactionCategorizing? = nil) -> BankAlertCategorizer {
        BankAlertCategorizer(isPremium: premium, useAI: useAI, rules: rules, ai: ai, language: "en")
    }

    // MARK: - Free

    @Test("Free users always get Other, even for a known merchant or with AI available")
    func freeGetsOther() async {
        let ai = MockCategorizer(answer: "food_drink")
        let result = await categorizer(premium: false, ai: ai).categorize(alert("GRAB*RIDE 1234"), in: context)
        #expect(result.categoryId == "other_expense")
        #expect(result.source == .fallback)
        #expect(ai.calls.isEmpty)

        let income = await categorizer(premium: false).categorize(alert("Luong thang 11", type: .income, guess: "salary"), in: context)
        #expect(income.categoryId == "other_income")
    }

    // MARK: - Premium order

    @Test("Premium: a rule wins over everything else")
    func ruleFirst() async {
        rules.set(note: "Shopee Pay", type: .expense, categoryId: "gifts")
        let result = await categorizer(premium: true, ai: MockCategorizer(answer: "shopping")).categorize(alert("SHOPEE PAY"), in: context)
        #expect(result == ("gifts", .rule))
    }

    @Test("Premium: the category last used for the same note comes next")
    func historyNext() async throws {
        context.insert(Transaction(id: "t1", amount: 1, note: "Tran Thi B (BIDV)", categoryId: "family", type: .expense))
        try context.save()
        let result = await categorizer(premium: true).categorize(alert("Tran Thi B (BIDV)"), in: context)
        #expect(result == ("family", .history))
    }

    @Test("Premium: known merchants come from the dictionary")
    func dictionary() async {
        let ai = MockCategorizer(answer: "shopping")
        let result = await categorizer(premium: true, ai: ai).categorize(alert("Thanh toan GrabFood don hang"), in: context)
        #expect(result == ("food_drink", .dictionary))
        #expect(ai.calls.isEmpty)
    }

    @Test("Premium: the parser's keyword guess is used before AI")
    func keywordGuess() async {
        let ai = MockCategorizer(answer: "bonus")
        let result = await categorizer(premium: true, ai: ai).categorize(alert("ACME chuyen khoan", type: .income, guess: "freelance"), in: context)
        #expect(result == ("freelance", .keyword))
        #expect(ai.calls.isEmpty)
    }

    @Test("Premium: AI decides when nothing else knows, from the note and the allowed categories only")
    func aiLast() async {
        let ai = MockCategorizer(answer: "health")
        let result = await categorizer(premium: true, ai: ai).categorize(alert("Phong tap Yoga Test"), in: context)
        #expect(result == ("health", .ai))
        let call = try? #require(ai.calls.first)
        #expect(call?.note == "Phong tap Yoga Test")
        #expect(call?.type == .expense)
        #expect(call?.allowed.contains("other_expense") == true)
        #expect(call?.allowed.contains("salary") == false)
    }

    @Test("Premium: an AI answer outside the allowed list, or no answer, falls back to Other")
    func aiInvalid() async {
        let invalid = await categorizer(premium: true, ai: MockCategorizer(answer: "salary")).categorize(alert("Phong tap Yoga Test"), in: context)
        #expect(invalid == ("other_expense", .fallback))
        let none = await categorizer(premium: true, ai: MockCategorizer(answer: nil)).categorize(alert("Phong tap Yoga Test"), in: context)
        #expect(none == ("other_expense", .fallback))
    }

    @Test("Premium with AI off never calls AI")
    func aiOff() async {
        let ai = MockCategorizer(answer: "health")
        let result = await categorizer(premium: true, useAI: false, ai: ai).categorize(alert("Phong tap Yoga Test"), in: context)
        #expect(result == ("other_expense", .fallback))
        #expect(ai.calls.isEmpty)
    }

    // MARK: - Dictionary

    @Test("Dictionary matches whole words, by type, specific entries first", arguments: [
        ("GRAB*RIDE HCM", TransactionType.expense, "transport"),
        ("GrabFood 123", .expense, "food_drink"),
        ("Highlands Coffee Q1", .expense, "food_drink"),
        ("THANH TOAN TIEN DIEN THANG 11", .expense, "bills_utilities"),
        ("Shopee", .expense, "shopping"),
        ("Luong thang 11", .income, "salary"),
        ("Hoàn tiền đơn hàng", .income, "refund"),
    ])
    func dictionaryMatches(_ note: String, _ type: TransactionType, _ expected: String) {
        #expect(MerchantDictionary.categoryId(for: note, type: type) == expected)
    }

    @Test("Dictionary ignores partial words and the wrong type", arguments: [
        ("Thanh pho Ho Chi Minh", TransactionType.expense),
        ("Nguyen Van Grabowski", .expense),
        ("Luong thang 11", .expense),
        ("Binh thuong", .income),
    ])
    func dictionaryMisses(_ note: String, _ type: TransactionType) {
        #expect(MerchantDictionary.categoryId(for: note, type: type) == nil)
    }

    // MARK: - Rules store

    @Test("Rules match without case or diacritics, and setting again updates")
    func rulesStore() {
        rules.set(note: "Trần Thị B (BIDV)", type: .expense, categoryId: "family")
        #expect(rules.rule(for: "tran thi b  (bidv)", type: .expense)?.categoryId == "family")
        #expect(rules.rule(for: "Tran Thi B (BIDV)", type: .income) == nil)

        rules.set(note: "Tran Thi B (BIDV)", type: .expense, categoryId: "gifts")
        #expect(rules.rules.count == 1)
        #expect(rules.rules.first?.categoryId == "gifts")

        rules.remove(id: rules.rules[0].id)
        #expect(rules.rules.isEmpty)
    }

    // MARK: - Uncategorized

    @Test("Uncategorized lists bank-alert transactions in Other that weren't kept as Other")
    func uncategorized() throws {
        let list = UncategorizedBankTransactions(defaults: defaults)
        let a = Transaction(id: "bankalert:vcb:1:-1", amount: 1, note: "A", categoryId: "other_expense", type: .expense)
        let b = Transaction(id: "bankalert:vcb:2:+1", amount: 1, note: "B", categoryId: "other_income", type: .income)
        let filed = Transaction(id: "bankalert:vcb:3:-1", amount: 1, note: "C", categoryId: "food_drink", type: .expense)
        let manual = Transaction(id: "manual", amount: 1, note: "D", categoryId: "other_expense", type: .expense)

        #expect(list.filter([a, b, filed, manual]).map(\.id) == [a.id, b.id])
        list.dismiss(id: a.id)
        #expect(list.filter([a, b, filed, manual]).map(\.id) == [b.id])
        #expect(!list.isUncategorized(a))
    }

    @Test("Assigning with remember files the others with the same note and makes a rule")
    func assignRemember() throws {
        let store = BankAlertStore(
            inbox: BankAlertInbox(defaults: defaults),
            preferences: PreferencesService(defaults: defaults),
            templates: BankAlertTemplateStore(defaults: defaults),
            rules: rules,
            uncategorized: UncategorizedBankTransactions(defaults: defaults)
        )
        let first = Transaction(id: "bankalert:vcb:1:-1", amount: 1, note: "Le Van C (ACB)", categoryId: "other_expense", type: .expense)
        let second = Transaction(id: "bankalert:vcb:2:-2", amount: 2, note: "le van c (acb)", categoryId: "other_expense", type: .expense)
        let other = Transaction(id: "bankalert:vcb:3:-3", amount: 3, note: "Someone Else", categoryId: "other_expense", type: .expense)
        [first, second, other].forEach(context.insert)
        try context.save()

        try store.assign(first, categoryId: "food_drink", remember: true, among: [first, second, other], in: context)

        #expect(first.categoryId == "food_drink")
        #expect(second.categoryId == "food_drink")
        #expect(other.categoryId == "other_expense")
        #expect(rules.rule(for: "Le Van C (ACB)", type: .expense)?.categoryId == "food_drink")
    }

    @Test("Assigning without remember changes only that transaction and makes no rule")
    func assignOnce() throws {
        let store = BankAlertStore(
            inbox: BankAlertInbox(defaults: defaults),
            preferences: PreferencesService(defaults: defaults),
            templates: BankAlertTemplateStore(defaults: defaults),
            rules: rules,
            uncategorized: UncategorizedBankTransactions(defaults: defaults)
        )
        let first = Transaction(id: "bankalert:vcb:1:-1", amount: 1, note: "Le Van C (ACB)", categoryId: "other_expense", type: .expense)
        let second = Transaction(id: "bankalert:vcb:2:-2", amount: 2, note: "Le Van C (ACB)", categoryId: "other_expense", type: .expense)
        [first, second].forEach(context.insert)
        try context.save()

        try store.assign(first, categoryId: "food_drink", remember: false, among: [first, second], in: context)

        #expect(second.categoryId == "other_expense")
        #expect(rules.rules.isEmpty)
    }

    @Test("Premium: changing the category while reviewing makes a rule; free doesn't")
    func approveMakesRule() throws {
        let inbox = BankAlertInbox(defaults: defaults)
        let store = BankAlertStore(
            inbox: inbox,
            preferences: PreferencesService(defaults: defaults),
            templates: BankAlertTemplateStore(defaults: defaults),
            rules: rules,
            uncategorized: UncategorizedBankTransactions(defaults: defaults)
        )
        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        func pending(_ id: String, note: String) -> PendingBankAlert {
            PendingBankAlert(id: id, bankId: "vcb", type: .expense, amount: 10, date: .now, note: note,
                             categoryId: "other_expense", walletId: Wallet.personalID, receivedAt: .now)
        }
        let freeItem = pending("bankalert:a", note: "Free Note")
        inbox.add(freeItem)
        try store.approve(freeItem, edited: Transaction(amount: 10, note: "Free Note", categoryId: "pets", type: .expense),
                          isPremium: false, in: context, balanceService: balance)
        #expect(rules.rules.isEmpty)

        let premiumItem = pending("bankalert:b", note: "Premium Note")
        inbox.add(premiumItem)
        try store.approve(premiumItem, edited: Transaction(amount: 10, note: "Premium Note", categoryId: "pets", type: .expense),
                          isPremium: true, in: context, balanceService: balance)
        #expect(rules.rule(for: "Premium Note", type: .expense)?.categoryId == "pets")
    }

    @Test("Gemini instructions say income or expense and how to answer when unsure")
    func geminiInstructions() {
        #expect(GeminiCategorizer.instructions(type: .expense).contains("other_expense"))
        #expect(GeminiCategorizer.instructions(type: .income).contains("other_income"))
    }
}

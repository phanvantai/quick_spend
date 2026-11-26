import Foundation
import SwiftData

// MARK: - Rules

/// "Always put transfers to <note> in <category>", created when a Premium user
/// categorises a bank-alert transaction.
struct CategoryRule: Codable, Identifiable, Equatable {
    let id: String
    /// The transaction note as shown, e.g. "Tran Thi B (TPBANK)".
    let note: String
    let type: TransactionType
    var categoryId: String
    let createdAt: Date

    /// Notes compare without case, diacritics or extra spaces.
    static func key(_ note: String) -> String {
        BankAlertText.fold(note).lowercased()
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// The user's category rules, kept in UserDefaults on this device.
final class BankAlertCategoryRules {
    static let shared = BankAlertCategoryRules(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "bank_alert_category_rules"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var rules: [CategoryRule] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([CategoryRule].self, from: data) else { return [] }
        return list
    }

    func rule(for note: String, type: TransactionType) -> CategoryRule? {
        let match = CategoryRule.key(note)
        return rules.first { $0.type == type && CategoryRule.key($0.note) == match }
    }

    /// Adds a rule, or changes the category of the one for the same note and type.
    func set(note: String, type: TransactionType, categoryId: String, now: Date = .now) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = rules
        if let index = list.firstIndex(where: { $0.type == type && CategoryRule.key($0.note) == CategoryRule.key(trimmed) }) {
            list[index].categoryId = categoryId
        } else {
            list.append(CategoryRule(id: UUID().uuidString, note: trimmed, type: type, categoryId: categoryId, createdAt: now))
        }
        save(list)
    }

    func remove(id: String) {
        save(rules.filter { $0.id != id })
    }

    private func save(_ list: [CategoryRule]) {
        if list.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .bankAlertInboxDidChange, object: nil)
    }
}

// MARK: - Merchant dictionary

/// Well-known Vietnamese merchants and payment words, matched offline against
/// the transaction note. More specific entries come first ("grabfood" before "grab").
enum MerchantDictionary {
    struct Entry {
        let keywords: [String]
        let categoryId: String
        let type: TransactionType
    }

    static let entries: [Entry] = [
        // Food delivery before ride-hailing, since both mention the app name.
        Entry(keywords: ["grabfood", "grab food", "shopeefood", "shopee food", "baemin", "befood", "be food"], categoryId: "food_drink", type: .expense),
        Entry(keywords: ["grab", "xanh sm", "xanhsm", "gsm", "be group", "begroup", "gojek", "taxi", "mai linh", "vinasun",
                         "petrolimex", "xang", "do xang", "gui xe", "vetc", "epass", "vdtc", "phi duong bo"], categoryId: "transport", type: .expense),
        Entry(keywords: ["vietjet", "vietnam airlines", "bamboo airways", "vietravel", "agoda", "booking.com", "traveloka",
                         "airbnb", "khach san", "hotel", "ve tau", "ve may bay"], categoryId: "travel", type: .expense),
        Entry(keywords: ["highlands", "phuc long", "starbucks", "the coffee house", "katinat", "cong caphe", "trung nguyen",
                         "kfc", "lotteria", "jollibee", "mcdonald", "pizza hut", "domino", "gong cha", "phe la",
                         "an sang", "an trua", "an toi", "an uong", "ca phe", "cafe", "coffee", "tra sua", "com trua"],
              categoryId: "food_drink", type: .expense),
        Entry(keywords: ["winmart", "vinmart", "bach hoa xanh", "bachhoaxanh", "coopmart", "co.op", "coop food", "lotte mart",
                         "aeon", "go mart", "big c", "mm mega", "emart", "circle k", "ministop", "familymart", "gs25", "7-eleven",
                         "di cho", "sieu thi"], categoryId: "groceries", type: .expense),
        Entry(keywords: ["shopee", "lazada", "tiki", "sendo", "tiktok shop", "uniqlo", "the gioi di dong", "thegioididong",
                         "dien may xanh", "fpt shop", "cellphones", "hoang ha mobile", "apple store"], categoryId: "shopping", type: .expense),
        Entry(keywords: ["evn", "tien dien", "dien luc", "tien nuoc", "cap nuoc", "viettel", "vnpt", "mobifone", "vinaphone",
                         "fpt telecom", "internet", "nap tien dien thoai", "phi dich vu", "quan ly chung cu"], categoryId: "bills_utilities", type: .expense),
        Entry(keywords: ["netflix", "spotify", "youtube", "apple.com", "icloud", "google one", "cgv", "lotte cinema", "galaxy cinema",
                         "bhd", "steam", "playstation", "ve xem phim"], categoryId: "entertainment", type: .expense),
        Entry(keywords: ["nha thuoc", "pharmacity", "long chau", "an khang", "benh vien", "phong kham", "nha khoa", "vinmec"],
              categoryId: "health", type: .expense),
        Entry(keywords: ["hoc phi", "khoa hoc", "udemy", "coursera", "fahasa", "tien hoc"], categoryId: "education", type: .expense),
        Entry(keywords: ["tien nha", "tien phong", "thue nha", "tien thue nha"], categoryId: "housing", type: .expense),
        Entry(keywords: ["bao hiem", "prudential", "manulife", "aia", "bao viet", "dai-ichi", "fwd"], categoryId: "insurance", type: .expense),
        Entry(keywords: ["tra no", "thanh toan the", "sao ke", "tra gop", "home credit", "fe credit", "hd saison", "mcredit"],
              categoryId: "debt_payment", type: .expense),
        Entry(keywords: ["cat toc", "spa", "salon", "nail", "gym", "california fitness"], categoryId: "personal_care", type: .expense),
        Entry(keywords: ["thu y", "pet shop", "petmart"], categoryId: "pets", type: .expense),
        Entry(keywords: ["mung cuoi", "dam cuoi", "mung sinh nhat", "qua tang"], categoryId: "gifts", type: .expense),
        Entry(keywords: ["chung khoan", "tiet kiem", "gui tiet kiem", "mua vang", "ssi", "vndirect", "tcbs"], categoryId: "savings_invest", type: .expense),

        Entry(keywords: ["luong", "salary", "payroll"], categoryId: "salary", type: .income),
        Entry(keywords: ["thu lao", "nhuan but", "freelance"], categoryId: "freelance", type: .income),
        Entry(keywords: ["tien thuong", "thuong tet", "thuong quy", "bonus"], categoryId: "bonus", type: .income),
        Entry(keywords: ["hoan tien", "refund", "cashback", "hoan tra"], categoryId: "refund", type: .income),
        Entry(keywords: ["tra lai", "tien lai", "lai tiet kiem", "interest"], categoryId: "interest", type: .income),
        Entry(keywords: ["co tuc", "dividend"], categoryId: "investment_income", type: .income),
        Entry(keywords: ["mung tuoi", "li xi", "qua tang", "mung cuoi"], categoryId: "gift_received", type: .income),
    ]

    /// The category of the first entry whose keyword appears as whole words in `text`.
    static func categoryId(for text: String, type: TransactionType) -> String? {
        let folded = BankAlertText.fold(text).lowercased()
        for entry in entries where entry.type == type {
            for keyword in entry.keywords {
                let pattern = #"(?<![a-z0-9])"# + NSRegularExpression.escapedPattern(for: keyword) + #"(?![a-z0-9])"#
                if folded.range(of: pattern, options: .regularExpression) != nil { return entry.categoryId }
            }
        }
        return nil
    }
}

// MARK: - AI

/// Picks a category for a short transaction note. Gemini in production, a
/// mock in tests.
@MainActor
protocol TransactionCategorizing {
    /// One of `allowedCategoryIds`, or nil when it can't tell.
    func categoryId(note: String, type: TransactionType, allowedCategoryIds: [String], language: String) async -> String?
}

// MARK: - Categorizer

/// Chooses the category for a bank-alert transaction.
///
/// Free: always "other" (the transaction then shows in "Uncategorized").
/// Premium, first that answers: the user's rule for this note, the category
/// last used for this note, the merchant dictionary, the parser's keyword
/// guess, then AI (when on). Otherwise "other".
@MainActor
struct BankAlertCategorizer {
    enum Source: Equatable {
        case rule, history, dictionary, keyword, ai, fallback
    }

    var isPremium: Bool
    var useAI: Bool
    var rules: BankAlertCategoryRules
    var ai: TransactionCategorizing?
    var language: String = "vi"

    static func fallbackCategoryId(for type: TransactionType) -> String {
        type == .income ? "other_income" : "other_expense"
    }

    func categorize(_ alert: BankAlert, in context: ModelContext) async -> (categoryId: String, source: Source) {
        let fallback = Self.fallbackCategoryId(for: alert.type)
        guard isPremium else { return (fallback, .fallback) }

        if let rule = rules.rule(for: alert.note, type: alert.type) { return (rule.categoryId, .rule) }
        if let previous = Self.lastUsedCategory(note: alert.note, type: alert.type, in: context), previous != fallback {
            return (previous, .history)
        }
        if let known = MerchantDictionary.categoryId(for: alert.note, type: alert.type) { return (known, .dictionary) }
        if alert.categoryId != fallback { return (alert.categoryId, .keyword) }

        if useAI, let ai {
            let allowed = Self.allowedCategoryIds(for: alert.type, in: context)
            if let picked = await ai.categoryId(note: alert.note, type: alert.type, allowedCategoryIds: allowed, language: language),
               allowed.contains(picked) {
                return (picked, picked == fallback ? .fallback : .ai)
            }
        }
        return (fallback, .fallback)
    }

    /// The user's visible categories of this type, plus the fallback.
    static func allowedCategoryIds(for type: TransactionType, in context: ModelContext) -> [String] {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var ids = categories.filter { $0.type == type && !$0.isHidden }.map(\.id)
        let fallback = fallbackCategoryId(for: type)
        if !ids.contains(fallback) { ids.append(fallback) }
        return ids
    }

    /// The category of the latest transaction with the same note and type.
    static func lastUsedCategory(note: String, type: TransactionType, in context: ModelContext) -> String? {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.note == note },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let matches = (try? context.fetch(descriptor)) ?? []
        return matches.first { $0.type == type && !$0.isTransfer }?.categoryId
    }
}

// MARK: - Uncategorized

/// Bank-alert transactions still in "other", which the user can sort out in
/// "Uncategorized". Ones the user chose to leave as "other" are remembered.
final class UncategorizedBankTransactions {
    static let shared = UncategorizedBankTransactions(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "bank_alert_uncategorized_dismissed"
    /// Older dismissals are forgotten; their transactions are long reviewed.
    static let dismissedCapacity = 500

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var dismissedIds: [String] { defaults.stringArray(forKey: key) ?? [] }

    func isUncategorized(_ transaction: Transaction) -> Bool {
        transaction.id.hasPrefix(BankAlertImportFlow.idPrefix)
            && transaction.categoryId == BankAlertCategorizer.fallbackCategoryId(for: transaction.type)
            && !dismissedIds.contains(transaction.id)
    }

    func filter(_ transactions: [Transaction]) -> [Transaction] {
        let dismissed = Set(dismissedIds)
        return transactions.filter {
            $0.id.hasPrefix(BankAlertImportFlow.idPrefix)
                && $0.categoryId == BankAlertCategorizer.fallbackCategoryId(for: $0.type)
                && !dismissed.contains($0.id)
        }
    }

    /// "Keep as other": stop listing it.
    func dismiss(id: String) {
        var list = dismissedIds.filter { $0 != id }
        list.append(id)
        defaults.set(Array(list.suffix(Self.dismissedCapacity)), forKey: key)
        NotificationCenter.default.post(name: .bankAlertInboxDidChange, object: nil)
    }
}

import Foundation

/// A bank QuickSpend can recognise in an alert.
///
/// `support` says how well its alerts are read: `.full` banks have a parser
/// written against real alerts, so their transactions are saved straight away;
/// `.beta` banks go through the generic parser and always wait for review.
struct BankInfo: Identifiable, Equatable, Hashable {
    enum Support: Equatable, Hashable {
        case full
        case beta
    }

    let id: String
    let name: String
    let support: Support
    /// Lowercase, diacritic-free words that identify the bank in an alert.
    let keywords: [String]

    static let vietcombank = BankInfo(id: "vcb", name: "Vietcombank", support: .full, keywords: ["vietcombank", "vcb"])

    /// Banks QuickSpend reads without a user template. For now only
    /// Vietcombank; other banks are added by the user with "Learn from a sample".
    static let all: [BankInfo] = [vietcombank]

    static func with(id: String?) -> BankInfo? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The first bank named in already-folded, lowercased text.
    static func detect(inFolded text: String) -> BankInfo? {
        for bank in all {
            for keyword in bank.keywords {
                let pattern = #"(?<![a-z0-9])"# + NSRegularExpression.escapedPattern(for: keyword) + #"(?![a-z0-9])"#
                if text.range(of: pattern, options: .regularExpression) != nil { return bank }
            }
        }
        return nil
    }
}

/// One balance change read from a bank alert. Holds no account number and no
/// balance: only what QuickSpend stores for the transaction.
struct BankAlert: Equatable {
    /// nil when the generic parser could not tell which bank sent it.
    let bank: BankInfo?
    let type: TransactionType
    let amount: Double
    let date: Date
    let note: String
    let categoryId: String
    /// True only when a bank-specific parser read the whole alert. Anything
    /// else waits for the user's review.
    let isVerified: Bool

    /// Stable for the same alert, e.g. `vcb:20261121083957:-25000`.
    let dedupeKey: String

    var signedAmount: Double { type == .income ? amount : -amount }

    /// The same alert attributed to `bank` (when the Shortcuts action says
    /// which bank sent it).
    func attributed(to bank: BankInfo) -> BankAlert {
        BankAlert(
            bank: bank,
            type: type,
            amount: amount,
            date: date,
            note: note == (self.bank?.name ?? "Bank") ? bank.name : note,
            categoryId: categoryId,
            isVerified: isVerified,
            dedupeKey: BankAlertText.dedupeKey(bank: bank, date: date, type: type, digits: String(Int(amount)))
        )
    }
}

/// Shared helpers for the alert parsers.
enum BankAlertText {
    /// Vietnamese banks print times in Vietnam time, wherever the phone is.
    static let timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!

    /// NFC, then without diacritics ("Số dư" → "So du"). Case and "đ" are kept.
    static func fold(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
    }

    static func date(day: Int, month: Int, year: Int, hour: Int, minute: Int, second: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }

    static func dedupeKey(bank: BankInfo?, date: Date, type: TransactionType, digits: String) -> String {
        "\(bank?.id ?? "bank"):\(stamp(date)):\(type == .income ? "+" : "-")\(digits)"
    }

    /// Drops account numbers, phone numbers and other long digit runs.
    static func scrubNumbers(_ text: String) -> String {
        text.replacingOccurrences(of: #"\S*\d{8,}\S*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:|-")))
    }

    /// "… toi <account> <NAME> tai <BANK>" (bank omitted inside the same bank).
    private static let recipient = try! NSRegularExpression(
        pattern: #"\btoi\s+\S+\s+(.+?)(?:\s+tai\s+([A-Za-z0-9]+))?\s*$"#,
        options: [.caseInsensitive]
    )
    /// "… CT tu <account> <NAME> toi …"
    private static let sender = try! NSRegularExpression(
        pattern: #"\bCT tu\s+\S+\s+(.+?)\s+toi\s"#,
        options: [.caseInsensitive]
    )

    /// For a transfer described in folded text: who the money went to
    /// (expense, "Tran Thi B (TPBANK)") or came from (income, "Tran Thi B").
    static func transferCounterparty(in text: String, type: TransactionType) -> String? {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        if type == .expense, let m = recipient.firstMatch(in: text, range: range) {
            let name = personName(ns.substring(with: m.range(at: 1)))
            guard !name.isEmpty else { return nil }
            if m.range(at: 2).location != NSNotFound {
                return "\(name) (\(ns.substring(with: m.range(at: 2)).uppercased()))"
            }
            return name
        }
        if type == .income, let m = sender.firstMatch(in: text, range: range) {
            let name = personName(ns.substring(with: m.range(at: 1)))
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private static func personName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespaces)
        if name.uppercased().hasPrefix("HO KINH DOANH ") {
            name = String(name.dropFirst("HO KINH DOANH ".count))
        }
        // An account number left in front of the name is not part of it.
        if name.range(of: #"\d{6,}"#, options: .regularExpression) != nil { return "" }
        return name.capitalized
    }

    /// Category guessed from the alert's description (folded text).
    static func category(for description: String, type: TransactionType) -> String {
        let text = description.lowercased()
        switch type {
        case .income:
            if text.contains("hoan tien") || text.contains("refund") || text.contains("cashback") { return "refund" }
            if text.contains("luong") || text.contains("salary") { return "salary" }
            if text.contains("thu lao") { return "freelance" }
            if text.contains("tra lai") || text.contains("tien lai") { return "interest" }
            return "other_income"
        case .expense:
            return "other_expense"
        }
    }
}

/// Reads any supported bank alert: the Vietcombank parser, then the user's
/// templates, then the generic parser for Vietcombank SMS and email. Alerts
/// from other banks without a template are not read.
enum BankAlertParser {
    static func parse(
        _ text: String,
        bankHint: BankInfo? = nil,
        templates: [BankAlertTemplate] = [],
        now: Date = .now
    ) -> BankAlert? {
        if let alert = VietcombankAlertParser.parse(text) { return alert }
        for template in templates {
            if let alert = template.parse(text, now: now) { return alert }
        }
        guard let generic = GenericBankAlertParser.parse(text, now: now) else { return nil }
        if let bankHint, BankInfo.all.contains(bankHint) { return generic.attributed(to: bankHint) }
        guard let bank = generic.bank, BankInfo.all.contains(bank) else { return nil }
        return generic
    }
}

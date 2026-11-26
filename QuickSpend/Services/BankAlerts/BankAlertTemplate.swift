import Foundation

/// A balance-alert format the user taught QuickSpend by pasting one alert and
/// picking its amount ("Learn from a sample"). Only the start of the alert, up
/// to the amount and date, becomes a pattern: fixed words stay as anchors and
/// every number becomes a placeholder, so no account number, balance or name
/// from the sample is kept.
struct BankAlertTemplate: Codable, Identifiable, Equatable {
    enum TypeRule: Codable, Equatable {
        /// "+" is income, "-" is expense.
        case fromSign
        /// The alert has no sign; every match is this type.
        case fixed(TransactionType)
    }

    /// Approvals without edits needed before matches are saved straight away.
    static let trustThreshold = 3

    let id: String
    var bankName: String
    /// NSRegularExpression pattern over diacritic-folded text, with named
    /// groups `sign`, `amount`, and optionally `day`/`month`/`year`, `hour`/`minute`/`second`.
    let pattern: String
    let typeRule: TypeRule
    /// The sample's start with numbers shown as placeholders, for Settings.
    let preview: String
    var approvedCount: Int = 0
    let createdAt: Date

    var isTrusted: Bool { approvedCount >= Self.trustThreshold }

    var bank: BankInfo {
        BankInfo(id: id, name: bankName, support: isTrusted ? .full : .beta, keywords: [])
    }

    /// Reads `text` with this template, or nil when it doesn't match.
    func parse(_ text: String, now: Date = .now) -> BankAlert? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let folded = BankAlertText.fold(text)
        let ns = folded as NSString
        guard let match = regex.firstMatch(in: folded, range: NSRange(location: 0, length: ns.length)) else { return nil }

        func named(_ name: String) -> String? {
            let range = match.range(withName: name)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
        guard let digits = named("amount")?.filter(\.isNumber), let amount = Double(digits), amount > 0 else { return nil }

        let type: TransactionType
        switch typeRule {
        case .fromSign:
            guard let sign = named("sign")?.trimmingCharacters(in: .whitespaces), !sign.isEmpty else { return nil }
            type = sign == "+" ? .income : .expense
        case .fixed(let fixed):
            type = fixed
        }

        var date = now
        if let day = named("day").flatMap(Int.init), let month = named("month").flatMap(Int.init),
           var year = named("year").flatMap(Int.init) {
            if year < 100 { year += 2000 }
            if let parsed = BankAlertText.date(
                day: day, month: month, year: year,
                hour: named("hour").flatMap(Int.init) ?? 0,
                minute: named("minute").flatMap(Int.init) ?? 0,
                second: named("second").flatMap(Int.init) ?? 0
            ), abs(parsed.timeIntervalSince(now)) <= GenericBankAlertParser.maxDateDrift {
                date = parsed
            }
        }

        let rest = ns.substring(from: match.range.upperBound)
        let described = GenericBankAlertParser.describe(rest, type: type, fallback: bankName)
        let bank = self.bank
        return BankAlert(
            bank: bank,
            type: type,
            amount: amount,
            date: date,
            note: described.note,
            categoryId: described.categoryId,
            isVerified: isTrusted,
            dedupeKey: BankAlertText.dedupeKey(bank: bank, date: date, type: type, digits: digits)
        )
    }
}

/// Builds a template from a pasted sample.
enum BankAlertTemplateBuilder {

    /// A number in the sample the user can pick as the amount.
    struct Candidate: Identifiable, Equatable {
        let id: Int
        /// As it appears, e.g. "-150,000".
        let text: String
        let hasSign: Bool
        let range: NSRange
    }

    enum BuildError: Error, Equatable {
        case emptyBankName
        case noAmount
        case doesNotMatchSample
        /// Too few fixed words before the amount to tell this format apart.
        case tooGeneric
    }

    private enum Kind { case date, time, number }
    private struct Token { let kind: Kind; let range: NSRange }

    private static let tokenRegex = try! NSRegularExpression(
        pattern: #"(?<date>(?<!\d)\d{1,2}[/-]\d{1,2}[/-](?:\d{4}|\d{2})(?!\d))|(?<time>(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d))|(?<number>(?:[+-]\s?)?\d+(?:[.,]\d+)*)"#
    )

    /// Text after the amount and date that the pattern may span; longer
    /// stretches are left to the description reader.
    private static let maxTailLength = 120

    private static func tokens(in folded: String) -> [Token] {
        let ns = folded as NSString
        return tokenRegex.matches(in: folded, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            if m.range(withName: "date").location != NSNotFound { return Token(kind: .date, range: m.range) }
            if m.range(withName: "time").location != NSNotFound { return Token(kind: .time, range: m.range) }
            return Token(kind: .number, range: m.range)
        }
    }

    /// Numbers that could be the amount: thousands separators, or 4–8 plain
    /// digits (longer plain runs are account or reference numbers).
    static func candidates(in sample: String) -> [Candidate] {
        let folded = BankAlertText.fold(sample)
        let ns = folded as NSString
        return tokens(in: folded).enumerated().compactMap { index, token in
            guard token.kind == .number else { return nil }
            let text = ns.substring(with: token.range).trimmingCharacters(in: .whitespaces)
            let digits = text.filter(\.isNumber)
            let grouped = text.dropFirst(text.first == "+" || text.first == "-" ? 1 : 0).contains { $0 == "," || $0 == "." }
            guard grouped || (4...8).contains(digits.count), digits.count <= 15, Int(digits) ?? 0 > 0 else { return nil }
            return Candidate(id: index, text: text, hasSign: text.hasPrefix("+") || text.hasPrefix("-"), range: token.range)
        }
    }

    /// Makes a template where `amount` (one of `candidates(in:)`) is the
    /// amount. `fixedType` is used only when the amount has no sign.
    static func build(
        sample: String,
        amount: Candidate,
        fixedType: TransactionType,
        bankName: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> BankAlertTemplate {
        let name = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw BuildError.emptyBankName }

        let folded = BankAlertText.fold(sample)
        let ns = folded as NSString
        let all = tokens(in: folded)
        guard all.contains(where: { $0.range == amount.range }) else { throw BuildError.noAmount }

        // The pattern runs to the amount, plus the first date and time when
        // they follow closely.
        var end = NSMaxRange(amount.range)
        let date = all.first { $0.kind == .date }
        let time = all.first { $0.kind == .time }
        for token in [date, time].compactMap({ $0 }) where NSMaxRange(token.range) - end <= maxTailLength {
            end = max(end, NSMaxRange(token.range))
        }

        var pattern = ""
        var preview = ""
        var cursor = 0
        for token in all where NSMaxRange(token.range) <= end {
            let literal = ns.substring(with: NSRange(location: cursor, length: token.range.location - cursor))
            pattern += literalPattern(literal)
            preview += literal
            if token.range == amount.range {
                pattern += #"(?<sign>[+-]?)\s?(?<amount>\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d{1,2})?"#
                preview += "[±amount]"
            } else if token.kind == .date, token.range == date?.range {
                pattern += #"(?<day>\d{1,2})[/-](?<month>\d{1,2})[/-](?<year>\d{4}|\d{2})"#
                preview += "[date]"
            } else if token.kind == .time, token.range == time?.range {
                pattern += #"(?<hour>\d{1,2}):(?<minute>\d{2})(?::(?<second>\d{2}))?"#
                preview += "[time]"
            } else {
                pattern += #"[+-]?\s?\d+(?:[.,:/-]\d+)*"#
                preview += "#"
            }
            cursor = NSMaxRange(token.range)
        }

        let literalLetters = preview
            .replacingOccurrences(of: #"\[[a-z±]+\]"#, with: "", options: .regularExpression)
            .filter(\.isLetter).count
        guard literalLetters >= 3 else { throw BuildError.tooGeneric }

        let template = BankAlertTemplate(
            id: id,
            bankName: name,
            pattern: pattern,
            typeRule: amount.hasSign ? .fromSign : .fixed(fixedType),
            preview: preview.trimmingCharacters(in: .whitespacesAndNewlines) + " …",
            createdAt: now
        )
        let expected = amount.text.filter(\.isNumber)
        guard let check = template.parse(sample, now: now), check.dedupeKey.hasSuffix(expected) else {
            throw BuildError.doesNotMatchSample
        }
        return template
    }

    /// Fixed words match case-insensitively with any spacing.
    private static func literalPattern(_ literal: String) -> String {
        let words = literal.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
        guard !words.isEmpty else { return literal.isEmpty ? "" : #"\s*"# }
        let lead = literal.first?.isWhitespace == true ? #"\s*"# : ""
        let trail = literal.last?.isWhitespace == true ? #"\s*"# : ""
        return lead + words.joined(separator: #"\s*"#) + trail
    }
}

/// The user's templates, kept in UserDefaults on this device.
final class BankAlertTemplateStore {
    static let shared = BankAlertTemplateStore(defaults: .standard)

    private let defaults: UserDefaults
    private let key = "bank_alert_templates"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var templates: [BankAlertTemplate] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([BankAlertTemplate].self, from: data) else { return [] }
        return list
    }

    func add(_ template: BankAlertTemplate) {
        save(templates.filter { $0.id != template.id } + [template])
    }

    func remove(id: String) {
        save(templates.filter { $0.id != id })
    }

    /// A match was saved as it was read.
    func recordApproval(id: String) {
        update(id) { $0.approvedCount += 1 }
    }

    /// A match needed edits: start counting again.
    func recordCorrection(id: String) {
        update(id) { $0.approvedCount = 0 }
    }

    private func update(_ id: String, _ change: (inout BankAlertTemplate) -> Void) {
        var list = templates
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        change(&list[index])
        save(list)
    }

    private func save(_ list: [BankAlertTemplate]) {
        if list.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .bankAlertInboxDidChange, object: nil)
    }
}

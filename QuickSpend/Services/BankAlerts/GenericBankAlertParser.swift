import Foundation

/// Best-effort reader for balance alerts from banks without their own parser,
/// and for bank SMS and email. Looks for a signed amount ("-50,000VND",
/// "GD: +1.200.000 VND") next to balance-alert words ("SD", "TK", "so du",
/// "giao dich"). Results are never `isVerified`, so they always wait for the
/// user's review.
enum GenericBankAlertParser {

    /// The signed amount: a currency after it, or thousands separators, so
    /// phone numbers ("+84…") and dates ("25-11-2026") don't match.
    private static let signedAmount = try! NSRegularExpression(
        pattern: #"(?<![\w.,])([+-])\s?((?:\d{1,3}(?:[.,]\d{3})+)|\d+)(?:[.,]\d{1,2})?(\s*(?:vnd|vnđ|đ|d)(?![a-z]))?"#,
        options: [.caseInsensitive]
    )
    private static let context = try! NSRegularExpression(
        pattern: #"(?<![a-z])(so du|sd|sdc|sdtk|tk|tai khoan|bien dong|giao dich|gd|ps)(?![a-z])"#,
        options: [.caseInsensitive]
    )
    private static let rejected = try! NSRegularExpression(
        pattern: #"(?<![a-z])(otp|ma xac thuc|ma xac nhan|khong thanh cong|that bai|bi tu choi|uu dai|khuyen mai)(?![a-z])"#,
        options: [.caseInsensitive]
    )
    private static let dayMonthYear = try! NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})(?!\d)"#)
    private static let time = try! NSRegularExpression(pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?::(\d{2}))?(?!\d)"#)
    private static let description = try! NSRegularExpression(
        pattern: #"(?<![a-z])(?:nd|noi dung(?: gd| giao dich)?|ref|mo ta|dien giai)(?![a-z])\s*[:.]?\s*(.+)$"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    /// How far an alert's own date may be from now before we distrust it.
    static let maxDateDrift: TimeInterval = 60 * 24 * 3600

    static func parse(_ text: String, now: Date = .now) -> BankAlert? {
        let folded = BankAlertText.fold(text).lowercased()
        let ns = folded as NSString
        let all = NSRange(location: 0, length: ns.length)

        guard rejected.firstMatch(in: folded, range: all) == nil,
              context.firstMatch(in: folded, range: all) != nil,
              let match = signedAmount.matches(in: folded, range: all).first(where: { m in
                  // A bare number needs thousands separators or a currency.
                  let number = ns.substring(with: m.range(at: 2))
                  return m.range(at: 3).location != NSNotFound || number.contains(",") || number.contains(".")
              })
        else { return nil }

        let digits = ns.substring(with: match.range(at: 2)).filter(\.isNumber)
        guard let amount = Double(digits), amount > 0 else { return nil }
        let type: TransactionType = ns.substring(with: match.range(at: 1)) == "+" ? .income : .expense

        let date = alertDate(in: folded, now: now) ?? now
        let bank = BankInfo.detect(inFolded: folded)
        let described = describe(BankAlertText.fold(text), type: type, fallback: bank?.name ?? "Bank")

        return BankAlert(
            bank: bank,
            type: type,
            amount: amount,
            date: date,
            note: described.note,
            categoryId: described.categoryId,
            isVerified: false,
            dedupeKey: BankAlertText.dedupeKey(bank: bank, date: date, type: type, digits: digits)
        )
    }

    /// Note and guessed category from an alert's description part: the
    /// transfer counterparty when there is one, else the description itself.
    static func describe(_ foldedText: String, type: TransactionType, fallback: String) -> (note: String, categoryId: String) {
        let rawDescription = descriptionText(in: foldedText)
        let counterparty = rawDescription.isEmpty ? nil : BankAlertText.transferCounterparty(in: rawDescription, type: type)
        let note = BankAlertText.scrubNumbers(counterparty ?? rawDescription)
        return (
            note.isEmpty ? fallback : String(note.prefix(80)),
            BankAlertText.category(for: rawDescription, type: type)
        )
    }

    /// The first day-month-year (and time) in folded text, if it is close to `now`.
    static func alertDate(in folded: String, now: Date) -> Date? {
        let ns = folded as NSString
        let all = NSRange(location: 0, length: ns.length)
        guard let d = dayMonthYear.firstMatch(in: folded, range: all) else { return nil }
        func int(_ m: NSTextCheckingResult, _ i: Int) -> Int? {
            m.range(at: i).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: i)))
        }
        guard let day = int(d, 1), let month = int(d, 2), var year = int(d, 3) else { return nil }
        if year < 100 { year += 2000 }
        let t = time.firstMatch(in: folded, range: all)
        let date = BankAlertText.date(
            day: day, month: month, year: year,
            hour: t.flatMap { int($0, 1) } ?? 0,
            minute: t.flatMap { int($0, 2) } ?? 0,
            second: t.flatMap { int($0, 3) } ?? 0
        )
        guard let date, abs(date.timeIntervalSince(now)) <= maxDateDrift else { return nil }
        return date
    }

    /// Text after "ND:", "Noi dung:", "Ref" …, cut at the next "|" or balance part.
    private static func descriptionText(in text: String) -> String {
        let ns = text as NSString
        guard let m = description.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return ""
        }
        var value = ns.substring(with: m.range(at: 1))
        if let bar = value.firstIndex(of: "|") { value = String(value[..<bar]) }
        value = value.replacingOccurrences(of: "\n", with: " ")
        value = value.replacingOccurrences(
            of: #"(?i)\s*\b(so du|sd|sdc)\b\s*[:.]?\s*[\d.,]+\s*(vnd|đ)?.*$"#, with: "", options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

/// Reads Vietcombank balance alerts ("biến động số dư") offline:
///
///     Số dư TK VCB 0123456789 -25,000 VND lúc 21-11-2026 08:39:57.
///     Số dư 1,234,567 VND. Ref MBVCB.….CT tu … toi 9876543210 TRAN THI B tai TPBANK
///
/// Written against real VCB Digibank notifications, so its results are
/// `isVerified`. Anything else (OTP, promotions, failed transfers) returns nil.
enum VietcombankAlertParser {

    // Matched against diacritic-folded text, so "Số dư … lúc" and "So du … luc" both work.
    private static let header = try! NSRegularExpression(
        pattern: #"so du tk vcb\s+\S+\s+([+-])\s*([\d.,]+)\s*vnd\s+luc\s+(\d{1,2})-(\d{1,2})-(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})"#,
        options: [.caseInsensitive]
    )
    private static let refStart = try! NSRegularExpression(pattern: #"\bref\s+"#, options: [.caseInsensitive])

    static func parse(_ text: String) -> BankAlert? {
        let folded = BankAlertText.fold(text)
        let ns = folded as NSString
        guard let match = header.firstMatch(in: folded, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        func group(_ i: Int) -> String { ns.substring(with: match.range(at: i)) }

        let digits = group(2).filter(\.isNumber)
        guard let amount = Double(digits), amount > 0 else { return nil }
        let type: TransactionType = group(1) == "+" ? .income : .expense

        let parts = (3...8).compactMap { Int(group($0)) }
        guard parts.count == 6, let date = BankAlertText.date(
            day: parts[0], month: parts[1], year: parts[2],
            hour: parts[3], minute: parts[4], second: parts[5]
        ) else { return nil }

        let ref = refText(in: ns.substring(from: match.range.upperBound))
        return BankAlert(
            bank: .vietcombank,
            type: type,
            amount: amount,
            date: date,
            note: makeNote(ref: ref, type: type),
            categoryId: BankAlertText.category(for: ref, type: type),
            isVerified: true,
            dedupeKey: BankAlertText.dedupeKey(bank: .vietcombank, date: date, type: type, digits: digits)
        )
    }

    // MARK: - Note

    private static func refText(in text: String) -> String {
        let ns = text as NSString
        guard let match = refStart.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return ""
        }
        return ns.substring(from: match.range.upperBound)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeNote(ref: String, type: TransactionType) -> String {
        let note = BankAlertText.transferCounterparty(in: ref, type: type) ?? description(ref: ref)
        let cleaned = BankAlertText.scrubNumbers(note)
        return cleaned.isEmpty ? BankInfo.vietcombank.name : cleaned
    }

    /// First "."-separated piece of the Ref that reads like words, e.g.
    /// "1234ABCD.ACME thanh toan thu lao Thang 10.2026.…" → "ACME thanh toan thu lao Thang 10".
    private static func description(ref: String) -> String {
        let pieces = ref.components(separatedBy: ".").map { $0.trimmingCharacters(in: .whitespaces) }
        guard var piece = pieces.first(where: isWords) else { return "" }
        // "LOYALTY_HOAN TIEN …" → "HOAN TIEN …"
        if let underscore = piece.firstIndex(of: "_"),
           !piece[..<underscore].contains(" ") {
            piece = String(piece[piece.index(after: underscore)...])
        }
        // Trailing transaction code: "… MA GD 1234567890"
        piece = piece.replacingOccurrences(
            of: #"\s+MA GD\s+\S+$"#, with: "", options: [.regularExpression, .caseInsensitive]
        )
        return piece.replacingOccurrences(of: "_", with: " ")
    }

    static func isWords(_ piece: String) -> Bool {
        let words = piece.split(separator: " ")
        return words.count >= 2 && words.contains { $0.count >= 2 && $0.allSatisfy(\.isLetter) }
    }
}

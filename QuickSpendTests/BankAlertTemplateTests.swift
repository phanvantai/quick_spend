import Testing
import Foundation
@testable import QuickSpend

/// Samples are made up; formats follow common Vietnamese bank alert shapes.
@Suite("BankAlertTemplate Tests")
struct BankAlertTemplateTests {

    /// Late November 2026, near the fixtures' dates.
    private let now = Date(timeIntervalSince1970: 1_795_740_000)

    private let pipeSample = "MBBANK: TK 01xxx789|GD: -150,000VND 25/11/26 12:30|SD: 2,000,000VND|ND: thanh toan tien dien"
    private let pipeOther = "MBBANK: TK 01xxx789|GD: +2,500,000VND 26/11/26 08:05|SD: 4,350,000VND|ND: Luong thang 11"

    private func build(_ sample: String, amount: String, type: TransactionType = .expense, name: String = "MB Bank") throws -> BankAlertTemplate {
        let candidate = try #require(BankAlertTemplateBuilder.candidates(in: sample).first { $0.text == amount })
        return try BankAlertTemplateBuilder.build(sample: sample, amount: candidate, fixedType: type, bankName: name, now: now, id: "tpl")
    }

    private func vnDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        BankAlertText.date(day: d, month: mo, year: y, hour: h, minute: mi, second: s)!
    }

    // MARK: - Candidates

    @Test("Long plain digit runs (account numbers) are not offered as the amount")
    func candidatesSkipAccountNumbers() {
        let texts = BankAlertTemplateBuilder.candidates(in: "TPBank: TK 0000111122 GD: -50,000VND 26/11/2026 09:00 SD: 900,000VND").map(\.text)
        #expect(texts == ["-50,000", "900,000"])
    }

    @Test("Amount candidates skip dates, times and short numbers")
    func candidates() {
        let texts = BankAlertTemplateBuilder.candidates(in: pipeSample).map(\.text)
        #expect(texts == ["-150,000", "2,000,000"])
        #expect(BankAlertTemplateBuilder.candidates(in: pipeSample).first?.hasSign == true)
    }

    // MARK: - Building and reading

    @Test("A template reads another alert of the same format")
    func readsSameFormat() throws {
        let template = try build(pipeSample, amount: "-150,000")
        let alert = try #require(template.parse(pipeOther, now: now))
        #expect(alert.type == .income)
        #expect(alert.amount == 2_500_000)
        #expect(alert.date == vnDate(2026, 11, 26, 8, 5))
        #expect(alert.note == "Luong thang 11")
        #expect(alert.categoryId == "salary")
        #expect(alert.bank?.name == "MB Bank")
        #expect(!alert.isVerified)
    }

    @Test("A template doesn't read a different format")
    func ignoresOtherFormats() throws {
        let template = try build(pipeSample, amount: "-150,000")
        #expect(template.parse("Số dư TK VCB 0123456789 -25,000 VND lúc 21-11-2026 08:39:57. Số dư 1 VND. Ref X", now: now) == nil)
        #expect(template.parse("Ma OTP cua ban la 482913", now: now) == nil)
    }

    @Test("Unsigned amounts use the type chosen when learning")
    func unsignedAmountUsesFixedType() throws {
        let sample = "ACB thong bao: TK 12345 giam 45,000 VND luc 21/11/2026 10:15. So du 900,000 VND. ND: cafe"
        let template = try build(sample, amount: "45,000", type: .expense, name: "ACB")
        #expect(template.typeRule == .fixed(.expense))
        let alert = try #require(template.parse("ACB thong bao: TK 12345 giam 120,000 VND luc 22/11/2026 19:00. So du 780,000 VND. ND: an toi", now: now))
        #expect(alert.type == .expense)
        #expect(alert.amount == 120_000)
        #expect(alert.note == "an toi")
    }

    @Test("A signed amount makes the sign decide the type")
    func signedTemplateUsesSign() throws {
        let template = try build(pipeSample, amount: "-150,000")
        #expect(template.typeRule == .fromSign)
    }

    @Test("The date and time are part of the pattern, so the alert's own time is used")
    func patternIncludesDateAndTime() throws {
        let template = try build(pipeSample, amount: "-150,000")
        #expect(template.pattern.contains("(?<day>"))
        #expect(template.pattern.contains("(?<hour>"))
        #expect(template.preview == "MBBANK: TK #xxx#|GD: [±amount]VND [date] [time] …")
    }

    @Test("The template keeps no account number, balance or description from the sample")
    func noPersonalDataKept() throws {
        let sample = "TPBank: TK 0000111122 GD: -50,000VND 20/11/2026 09:00 SD: 987,654VND ND: chuyen tien cho NGUYEN VAN A"
        let template = try build(sample, amount: "-50,000", name: "TPBank")
        for secret in ["0000111122", "987", "654", "NGUYEN", "chuyen"] {
            #expect(!template.pattern.contains(secret))
            #expect(!template.preview.contains(secret))
        }
    }

    @Test("Building fails without a bank name or with too few fixed words")
    func buildFailures() throws {
        let candidate = try #require(BankAlertTemplateBuilder.candidates(in: pipeSample).first)
        #expect(throws: BankAlertTemplateBuilder.BuildError.emptyBankName) {
            try BankAlertTemplateBuilder.build(sample: pipeSample, amount: candidate, fixedType: .expense, bankName: "  ", now: now)
        }
        let bare = "-50,000 12/11/2026"
        let bareCandidate = try #require(BankAlertTemplateBuilder.candidates(in: bare).first)
        #expect(throws: BankAlertTemplateBuilder.BuildError.tooGeneric) {
            try BankAlertTemplateBuilder.build(sample: bare, amount: bareCandidate, fixedType: .expense, bankName: "X", now: now)
        }
    }

    @Test("A trusted template's results are verified")
    func trusted() throws {
        var template = try build(pipeSample, amount: "-150,000")
        template.approvedCount = BankAlertTemplate.trustThreshold
        #expect(template.isTrusted)
        #expect(try #require(template.parse(pipeOther, now: now)).isVerified)
    }

    // MARK: - Store

    @Test("Store adds, counts approvals, resets on correction and removes")
    func store() throws {
        let store = BankAlertTemplateStore(defaults: UserDefaults(suiteName: "BankAlertTemplateTests-\(UUID().uuidString)")!)
        let template = try build(pipeSample, amount: "-150,000")
        store.add(template)
        store.recordApproval(id: "tpl")
        store.recordApproval(id: "tpl")
        #expect(store.templates.first?.approvedCount == 2)
        store.recordCorrection(id: "tpl")
        #expect(store.templates.first?.approvedCount == 0)
        store.remove(id: "tpl")
        #expect(store.templates.isEmpty)
    }

    @Test("Templates survive encoding (both type rules)")
    func codable() throws {
        let a = try build(pipeSample, amount: "-150,000")
        let b = BankAlertTemplate(id: "b", bankName: "B", pattern: "x", typeRule: .fixed(.income), preview: "x", createdAt: now)
        let data = try JSONEncoder().encode([a, b])
        #expect(try JSONDecoder().decode([BankAlertTemplate].self, from: data) == [a, b])
    }
}

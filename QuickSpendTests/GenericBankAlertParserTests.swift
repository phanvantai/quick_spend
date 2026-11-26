import Testing
import Foundation
@testable import QuickSpend

/// Every alert here is made up: the formats follow common Vietnamese bank SMS
/// shapes, but accounts, names and amounts are fake.
@Suite("GenericBankAlertParser Tests")
struct GenericBankAlertParserTests {

    /// Late November 2026, near the fixtures' dates.
    private let now = Date(timeIntervalSince1970: 1_795_740_000)

    private func vnDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        BankAlertText.date(day: d, month: mo, year: y, hour: h, minute: mi, second: s)!
    }

    @Test("Pipe-separated SMS: amount, date, bank and description")
    func pipeSeparated() throws {
        let text = "MBBANK: TK 01xxx789|GD: -150,000VND 25/11/26 12:30|SD: 2,000,000VND|ND: thanh toan tien dien"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.type == .expense)
        #expect(alert.amount == 150_000)
        #expect(alert.date == vnDate(2026, 11, 25, 12, 30))
        #expect(alert.bank == nil) // only Vietcombank is a known bank for now
        #expect(alert.note == "thanh toan tien dien")
        #expect(!alert.isVerified)
    }

    @Test("Dot thousands separators and income")
    func dotSeparatorsIncome() throws {
        let text = "Techcombank: TK 1903xxxx5678 +2.500.000 VND luc 24/11/2026 09:15:00. So du 10.000.000 VND. Noi dung: Luong thang 11"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.type == .income)
        #expect(alert.amount == 2_500_000)
        #expect(alert.date == vnDate(2026, 11, 24, 9, 15, 0))
        #expect(alert.bank == nil)
        #expect(alert.categoryId == "salary")
        #expect(alert.note == "Luong thang 11")
    }

    @Test("An amount in đồng with the 'đ' sign")
    func dongSign() throws {
        let text = "BIDV: Bien dong so du TK 1234xxx: -35.000đ ngay 23/11/2026 18:00. ND: an trua"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.amount == 35_000)
        #expect(alert.bank == nil)
    }

    @Test("A transfer description is shortened to the recipient, as for Vietcombank")
    func transferRecipient() throws {
        let text = "VCB: TK 0123 GD: -70,000VND 26/11/2026 06:54. SD: 1,000VND. ND: MBVCB.1.2.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi 9876543210 TRAN THI B tai BIDV"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.note == "Tran Thi B (BIDV)")
    }

    @Test("Unknown bank still parses, with a generic note when there is no description")
    func unknownBank() throws {
        let text = "TK 999xxx GD: -60,000VND 22/11/2026 07:00 SD: 1,000,000VND"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.bank == nil)
        #expect(alert.note == "Bank")
        #expect(alert.dedupeKey.hasPrefix("bank:"))
    }

    @Test("No date in the alert: the time it arrived is used")
    func noDateUsesNow() throws {
        let text = "ACB: TK 12345 GD -45,000 VND. SD 500,000 VND. ND: cafe"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.date == now)
    }

    @Test("A date far from today is not trusted")
    func farDateIgnored() throws {
        let text = "VPBank: TK 123 GD: -10,000VND 01/01/2019 07:00 SD: 1,000VND"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.date == now)
    }

    @Test("Account numbers and long codes never reach the note")
    func noteScrubbed() throws {
        let text = "VIB: TK 0000111122223333 GD: -20,000VND 21/11/2026 10:00. ND: chuyen tien cho 0987654321 ma 123456789012"
        let alert = try #require(GenericBankAlertParser.parse(text, now: now))
        #expect(alert.note.range(of: #"\d{8,}"#, options: .regularExpression) == nil)
    }

    @Test("Messages that are not balance changes are ignored", arguments: [
        "Ma OTP cua ban la 482913. Khong chia se ma nay.",
        "Giao dich -50,000VND khong thanh cong. Vui long thu lai.",
        "Uu dai -50% cho chu the khi mua sam cuoi tuan",
        "Hen gap ban luc 10:30 ngay 25/11/2026 tai chi nhanh",
        "Goi tong dai +84 901 234 567 de duoc ho tro tai khoan",
        "Chuc mung sinh nhat quy khach!",
        "",
    ])
    func ignored(_ text: String) {
        #expect(GenericBankAlertParser.parse(text, now: now) == nil)
    }

    @Test("BankAlertParser prefers the Vietcombank parser and its verified result")
    func dispatcherPrefersVerified() throws {
        let vcb = "Số dư TK VCB 0123456789 -25,000 VND lúc 21-11-2026 08:39:57. Số dư 1,234,567 VND. Ref X"
        #expect(try #require(BankAlertParser.parse(vcb, now: now)).isVerified)
        let sms = "VCB: TK 0123 GD: -25,000VND 21/11/2026 08:40 SD: 1,000VND"
        let generic = try #require(BankAlertParser.parse(sms, now: now))
        #expect(!generic.isVerified)
        #expect(generic.bank?.id == "vcb")
    }

    @Test("Bank detection matches whole words only")
    func bankDetectionWholeWords() {
        #expect(BankInfo.detect(inFolded: "chuyen khoan tu vcb toi")?.id == "vcb")
        #expect(BankInfo.detect(inFolded: "abcvcbx") == nil)
    }

    // MARK: - Vietcombank only

    @Test("Other banks' alerts are not read without a learned format")
    func otherBanksIgnored() {
        let text = "TPBank: TK 0000111122 GD: -120,000VND 21/11/2026 10:15 SD: 900,000VND ND: an trua"
        #expect(BankAlertParser.parse(text, now: now) == nil)
    }

    @Test("An SMS that doesn't name the bank is read when the action says it's Vietcombank")
    func bankHintAttributes() throws {
        let sms = "SD TK 0123 -45,000VND luc 21/11/2026 10:15. SD 900,000VND. ND: an trua"
        #expect(BankAlertParser.parse(sms, now: now) == nil)
        let alert = try #require(BankAlertParser.parse(sms, bankHint: .vietcombank, now: now))
        #expect(alert.bank == .vietcombank)
        #expect(!alert.isVerified)
        #expect(alert.dedupeKey.hasPrefix("vcb:"))
    }
}

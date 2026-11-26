import Testing
import Foundation
@testable import QuickSpend

/// Fixtures copy the shape of real Vietcombank balance alerts, but every
/// account number, name and reference below is made up.
@Suite("VietcombankAlertParser Tests")
struct VietcombankAlertParserTests {

    private let transferOut = "Số dư TK VCB 0123456789 -25,000 VND lúc 21-11-2026 08:39:57. Số dư 1,234,567 VND. Ref MBVCB.11111111111.ABC123DEF.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi 9876543210 TRAN THI B tai TPBANK"

    private let householdBusiness = "Số dư TK VCB 0123456789 -45,000 VND lúc 22-11-2026 12:05:00. Số dư 1,189,567 VND. Ref MBVCB.22222222222.XYZ.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi MS00P0000000000001 HO KINH DOANH LE VAN C tai TECHCOMBANK"

    private let companyIncome = "Số dư TK VCB 0123456789 +1,500,000 VND lúc 20-11-2026 11:00:47. Số dư 2,000,000 VND. Ref 1234ABCDEFGH.ACME thanh toan thu lao Thang 10.2026.20261120.110047.VND10000000000 01.CONG TY TNHH ACME.970400"

    private let cashback = "Số dư TK VCB 0123456789 +9,462 VND lúc 20-11-2026 09:19:36. Số dư 500,000 VND. Ref LOYALTY_HOAN TIEN THE VCB DIGICARD KY T10/2026 MA GD 12345678901234567890"

    private let walletTopUp = "Số dư TK VCB 0123456789 -4,233,075 VND lúc 24-11-2026 09:45:07. Số dư 300,000 VND. Ref Ecom.EW00000000000001.VED.0900000000.CashIn.abc123def456"

    private let incomingTransfer = "Số dư TK VCB 0123456789 +200,000 VND lúc 23-11-2026 18:58:07. Số dư 700,000 VND. Ref MBVCB.33333333333.QWE.TRAN THI B chuyen tien.CT tu 9876543210 TRAN THI B toi 0123456789 NGUYEN VAN A"

    private func vnDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    // MARK: - Amount, sign, date

    @Test("Outgoing transfer is an expense with amount, Vietnam-time date and recipient note")
    func transferOutIsExpense() throws {
        let alert = try #require(VietcombankAlertParser.parse(transferOut))
        #expect(alert.type == .expense)
        #expect(alert.amount == 25_000)
        #expect(alert.date == vnDate(2026, 11, 21, 8, 39, 57))
        #expect(alert.note == "Tran Thi B (TPBANK)")
        #expect(alert.categoryId == "other_expense")
        #expect(alert.bank == .vietcombank)
    }

    @Test("Household-business prefix is dropped from the recipient")
    func householdBusinessPrefixDropped() throws {
        let alert = try #require(VietcombankAlertParser.parse(householdBusiness))
        #expect(alert.note == "Le Van C (TECHCOMBANK)")
        #expect(alert.amount == 45_000)
    }

    @Test("Incoming transfer is income noted with the sender's name")
    func incomingTransferUsesSender() throws {
        let alert = try #require(VietcombankAlertParser.parse(incomingTransfer))
        #expect(alert.type == .income)
        #expect(alert.amount == 200_000)
        #expect(alert.note == "Tran Thi B")
        #expect(alert.categoryId == "other_income")
    }

    @Test("Company payment uses the first descriptive Ref segment and maps teaching fees to freelance")
    func companyIncomeIsFreelance() throws {
        let alert = try #require(VietcombankAlertParser.parse(companyIncome))
        #expect(alert.type == .income)
        #expect(alert.amount == 1_500_000)
        #expect(alert.note == "ACME thanh toan thu lao Thang 10")
        #expect(alert.categoryId == "freelance")
    }

    @Test("Card cashback is a refund with the transaction code stripped")
    func cashbackIsRefund() throws {
        let alert = try #require(VietcombankAlertParser.parse(cashback))
        #expect(alert.type == .income)
        #expect(alert.amount == 9_462)
        #expect(alert.note == "HOAN TIEN THE VCB DIGICARD KY T10/2026")
        #expect(alert.categoryId == "refund")
    }

    @Test("A Ref with no readable words falls back to the bank name")
    func codeOnlyRefFallsBack() throws {
        let alert = try #require(VietcombankAlertParser.parse(walletTopUp))
        #expect(alert.type == .expense)
        #expect(alert.amount == 4_233_075)
        #expect(alert.note == "Vietcombank")
    }

    @Test("Alerts without Vietnamese diacritics still parse")
    func withoutDiacritics() throws {
        let text = "So du TK VCB 0123456789 -10,000 VND luc 01-12-2026 07:00:00. So du 1,000 VND. Ref MBVCB.1.2.NGUYEN VAN A chuyen tien.CT tu 0123456789 NGUYEN VAN A toi 9876543210 TRAN THI B tai BIDV"
        let alert = try #require(VietcombankAlertParser.parse(text))
        #expect(alert.amount == 10_000)
        #expect(alert.note == "Tran Thi B (BIDV)")
    }

    @Test("Decomposed (NFD) Vietnamese text parses like composed text")
    func decomposedUnicode() throws {
        let nfd = transferOut.decomposedStringWithCanonicalMapping
        let alert = try #require(VietcombankAlertParser.parse(nfd))
        #expect(alert.amount == 25_000)
    }

    @Test("A notification title before the body is ignored")
    func titleBeforeBody() throws {
        let alert = try #require(VietcombankAlertParser.parse("Vietcombank\n" + transferOut))
        #expect(alert.amount == 25_000)
    }

    // MARK: - Privacy

    @Test("Notes never contain account numbers or the balance", arguments: [
        "transferOut", "householdBusiness", "companyIncome", "cashback", "walletTopUp", "incomingTransfer",
    ])
    func notesHaveNoAccountNumbers(_ name: String) throws {
        let text = [
            "transferOut": transferOut, "householdBusiness": householdBusiness,
            "companyIncome": companyIncome, "cashback": cashback,
            "walletTopUp": walletTopUp, "incomingTransfer": incomingTransfer,
        ][name]!
        let alert = try #require(VietcombankAlertParser.parse(text))
        #expect(alert.note.range(of: #"\d{8,}"#, options: .regularExpression) == nil)
        #expect(!alert.note.contains("0123456789"))
        #expect(!alert.dedupeKey.contains("0123456789"))
    }

    // MARK: - Ignored messages

    @Test("OTP, promotions and empty text are ignored", arguments: [
        "Ma OTP cua Quy khach la 123456. Tuyet doi KHONG chia se ma OTP.",
        "Vietcombank uu dai 50% khi thanh toan bang the VCB Visa. Chi tiet tai vietcombank.com.vn",
        "Giao dich chuyen tien 100,000 VND khong thanh cong.",
        "",
    ])
    func ignoresNonBalanceMessages(_ text: String) {
        #expect(VietcombankAlertParser.parse(text) == nil)
    }

    @Test("A zero amount is ignored")
    func zeroAmountIgnored() {
        let text = "Số dư TK VCB 0123456789 -0 VND lúc 21-11-2026 08:39:57. Số dư 1 VND. Ref X"
        #expect(VietcombankAlertParser.parse(text) == nil)
    }

    // MARK: - Dedupe key

    @Test("The same alert always gives the same key; a different time or amount gives another")
    func dedupeKey() throws {
        let a = try #require(VietcombankAlertParser.parse(transferOut))
        let again = try #require(VietcombankAlertParser.parse("Vietcombank\n" + transferOut))
        let other = try #require(VietcombankAlertParser.parse(householdBusiness))
        #expect(a.dedupeKey == again.dedupeKey)
        #expect(a.dedupeKey != other.dedupeKey)
        #expect(a.dedupeKey == "vcb:20261121083957:-25000")
    }
}

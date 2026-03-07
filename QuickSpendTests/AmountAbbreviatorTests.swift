import Testing
import Foundation
@testable import QuickSpend

@Suite("AmountAbbreviator Tests")
struct AmountAbbreviatorTests {

    // MARK: - VND

    @Test("VND abbreviates trillions with T")
    func testVNDTrillions() {
        #expect(AmountAbbreviator.abbreviate(1_000_000_000, currency: "VND", language: "vi") == "1 T")
        #expect(AmountAbbreviator.abbreviate(2_500_000_000, currency: "VND", language: "vi") == "2.5 T")
    }

    @Test("VND abbreviates millions with Tr")
    func testVNDMillions() {
        #expect(AmountAbbreviator.abbreviate(1_000_000, currency: "VND", language: "vi") == "1 Tr")
        #expect(AmountAbbreviator.abbreviate(15_000_000, currency: "VND", language: "vi") == "15 Tr")
        #expect(AmountAbbreviator.abbreviate(1_500_000, currency: "VND", language: "vi") == "1.5 Tr")
    }

    @Test("VND abbreviates thousands with K")
    func testVNDThousands() {
        #expect(AmountAbbreviator.abbreviate(1_000, currency: "VND", language: "vi") == "1 K")
        #expect(AmountAbbreviator.abbreviate(50_000, currency: "VND", language: "vi") == "50 K")
        #expect(AmountAbbreviator.abbreviate(500_000, currency: "VND", language: "vi") == "500 K")
    }

    @Test("VND shows raw amount below 1000")
    func testVNDSmallAmount() {
        #expect(AmountAbbreviator.abbreviate(500, currency: "VND", language: "vi") == "500")
        #expect(AmountAbbreviator.abbreviate(0, currency: "VND", language: "vi") == "0")
    }

    // MARK: - JPY

    @Test("JPY abbreviates 100M+ with 億")
    func testJPYOku() {
        #expect(AmountAbbreviator.abbreviate(100_000_000, currency: "JPY", language: "ja") == "1億")
        #expect(AmountAbbreviator.abbreviate(500_000_000, currency: "JPY", language: "ja") == "5億")
    }

    @Test("JPY abbreviates 10K+ with 万")
    func testJPYMan() {
        #expect(AmountAbbreviator.abbreviate(10_000, currency: "JPY", language: "ja") == "1万")
        #expect(AmountAbbreviator.abbreviate(50_000, currency: "JPY", language: "ja") == "5万")
        #expect(AmountAbbreviator.abbreviate(250_000, currency: "JPY", language: "ja") == "25万")
    }

    @Test("JPY shows raw amount below 10K")
    func testJPYSmallAmount() {
        #expect(AmountAbbreviator.abbreviate(5000, currency: "JPY", language: "ja") == "5000")
        #expect(AmountAbbreviator.abbreviate(500, currency: "JPY", language: "ja") == "500")
    }

    // MARK: - KRW

    @Test("KRW abbreviates 100M+ with 억")
    func testKRWOk() {
        #expect(AmountAbbreviator.abbreviate(100_000_000, currency: "KRW", language: "ko") == "1억")
    }

    @Test("KRW abbreviates 10K+ with 만")
    func testKRWMan() {
        #expect(AmountAbbreviator.abbreviate(10_000, currency: "KRW", language: "ko") == "1만")
        #expect(AmountAbbreviator.abbreviate(100_000, currency: "KRW", language: "ko") == "10만")
    }

    @Test("KRW shows raw amount below 10K")
    func testKRWSmallAmount() {
        #expect(AmountAbbreviator.abbreviate(5000, currency: "KRW", language: "ko") == "5000")
    }

    // MARK: - USD / EUR / THB (Default)

    @Test("USD abbreviates millions with M")
    func testUSDMillions() {
        #expect(AmountAbbreviator.abbreviate(1_000_000, currency: "USD", language: "en") == "1M")
        #expect(AmountAbbreviator.abbreviate(2_500_000, currency: "USD", language: "en") == "2.5M")
    }

    @Test("USD abbreviates thousands with K")
    func testUSDThousands() {
        #expect(AmountAbbreviator.abbreviate(1_000, currency: "USD", language: "en") == "1K")
        #expect(AmountAbbreviator.abbreviate(50_000, currency: "USD", language: "en") == "50K")
        #expect(AmountAbbreviator.abbreviate(1_500, currency: "USD", language: "en") == "1.5K")
    }

    @Test("USD shows raw amount below 1K")
    func testUSDSmallAmount() {
        #expect(AmountAbbreviator.abbreviate(500, currency: "USD", language: "en") == "500")
        #expect(AmountAbbreviator.abbreviate(99.5, currency: "USD", language: "en") == "99.5")
    }

    @Test("EUR abbreviates same as USD")
    func testEURMillions() {
        #expect(AmountAbbreviator.abbreviate(1_000_000, currency: "EUR", language: "es") == "1M")
        #expect(AmountAbbreviator.abbreviate(5_000, currency: "EUR", language: "es") == "5K")
    }

    @Test("THB abbreviates same as USD")
    func testTHBAbbreviation() {
        #expect(AmountAbbreviator.abbreviate(1_000_000, currency: "THB", language: "en") == "1M")
        #expect(AmountAbbreviator.abbreviate(50_000, currency: "THB", language: "en") == "50K")
    }

    // MARK: - Negative Amounts

    @Test("Negative amounts have minus sign")
    func testNegativeAmounts() {
        #expect(AmountAbbreviator.abbreviate(-50_000, currency: "VND", language: "vi") == "-50 K")
        #expect(AmountAbbreviator.abbreviate(-1_000_000, currency: "USD", language: "en") == "-1M")
        #expect(AmountAbbreviator.abbreviate(-50_000, currency: "JPY", language: "ja") == "-5万")
    }

    // MARK: - Edge Cases

    @Test("Zero amount")
    func testZeroAmount() {
        #expect(AmountAbbreviator.abbreviate(0, currency: "USD", language: "en") == "0")
        #expect(AmountAbbreviator.abbreviate(0, currency: "VND", language: "vi") == "0")
        #expect(AmountAbbreviator.abbreviate(0, currency: "JPY", language: "ja") == "0")
    }

    @Test("Trailing .0 is removed")
    func testTrailingZeroRemoved() {
        // 8.0 Tr → should be "8 Tr" not "8.0 Tr"
        #expect(AmountAbbreviator.abbreviate(8_000_000, currency: "VND", language: "vi") == "8 Tr")
        #expect(AmountAbbreviator.abbreviate(8_000, currency: "USD", language: "en") == "8K")
    }

    @Test("Non-trailing decimal preserved")
    func testDecimalPreserved() {
        #expect(AmountAbbreviator.abbreviate(1_500_000, currency: "VND", language: "vi") == "1.5 Tr")
        #expect(AmountAbbreviator.abbreviate(2_500, currency: "USD", language: "en") == "2.5K")
    }
}

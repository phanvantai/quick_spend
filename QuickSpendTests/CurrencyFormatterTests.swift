import Testing
import Foundation
@testable import QuickSpend

@Suite("CurrencyFormatter Tests")
struct CurrencyFormatterTests {

    // MARK: - format with AppConfig

    @Test("Format USD amount")
    func testFormatUSD() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = CurrencyFormatter.format(1234.56, config: config)
        #expect(result.contains("$"))
        #expect(result.contains("1,234.56"))
    }

    @Test("Format VND amount")
    func testFormatVND() {
        var config = AppConfig()
        config.language = "vi"
        config.currency = "VND"
        let result = CurrencyFormatter.format(1500000, config: config)
        #expect(result.contains("₫"))
        #expect(result.contains("1.500.000"))
    }

    @Test("Format JPY amount")
    func testFormatJPY() {
        let config = AppConfig(language: "ja", currency: "JPY")
        let result = CurrencyFormatter.format(15000, config: config)
        #expect(result.contains("¥"))
        #expect(result.contains("15,000"))
    }

    @Test("Format EUR amount")
    func testFormatEUR() {
        let config = AppConfig(language: "en", currency: "EUR")
        let result = CurrencyFormatter.format(1234.56, config: config)
        #expect(result.contains("€"))
        #expect(result.contains("1,234.56"))
    }

    // MARK: - format with explicit params

    @Test("Format with explicit currency and language")
    func testFormatExplicit() {
        let result = CurrencyFormatter.format(1000, currency: "USD", language: "en")
        #expect(result.contains("$"))
        #expect(result.contains("1,000.00"))
    }

    @Test("Format VND with explicit params uses period separators")
    func testFormatVNDExplicit() {
        let result = CurrencyFormatter.format(500000, currency: "VND", language: "vi")
        #expect(result.contains("500.000"))
    }

    // MARK: - formatNumber (without symbol)

    @Test("formatNumber USD")
    func testFormatNumberUSD() {
        let result = CurrencyFormatter.formatNumber(1234.56, currency: "USD", language: "en")
        #expect(result == "1,234.56")
    }

    @Test("formatNumber VND no decimals")
    func testFormatNumberVND() {
        let result = CurrencyFormatter.formatNumber(1500000, currency: "VND", language: "vi")
        #expect(result == "1.500.000")
    }

    @Test("formatNumber JPY no decimals")
    func testFormatNumberJPY() {
        let result = CurrencyFormatter.formatNumber(15000, currency: "JPY", language: "en")
        #expect(result == "15,000")
    }

    @Test("formatNumber KRW no decimals")
    func testFormatNumberKRW() {
        let result = CurrencyFormatter.formatNumber(50000, currency: "KRW", language: "en")
        #expect(result == "50,000")
    }

    @Test("formatNumber with period separator for Vietnamese")
    func testFormatNumberVietnamese() {
        let result = CurrencyFormatter.formatNumber(1234.56, currency: "USD", language: "vi")
        #expect(result == "1.234,56")
    }

    @Test("formatNumber with period separator for Spanish")
    func testFormatNumberSpanish() {
        let result = CurrencyFormatter.formatNumber(1234.56, currency: "EUR", language: "es")
        #expect(result == "1234,56")
    }

    @Test("formatNumber zero amount")
    func testFormatNumberZero() {
        let result = CurrencyFormatter.formatNumber(0, currency: "USD", language: "en")
        #expect(result == "0.00")
    }

    @Test("formatNumber large amount")
    func testFormatNumberLargeAmount() {
        let result = CurrencyFormatter.formatNumber(999999999, currency: "VND", language: "vi")
        #expect(result == "999.999.999")
    }

    @Test("formatNumber small decimal")
    func testFormatNumberSmallDecimal() {
        let result = CurrencyFormatter.formatNumber(0.01, currency: "USD", language: "en")
        #expect(result == "0.01")
    }
}

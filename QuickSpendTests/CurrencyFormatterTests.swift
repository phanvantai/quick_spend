import Testing
import Foundation
@testable import QuickSpend

@Suite("AppConfig Currency Formatting Tests")
struct CurrencyFormatterTests {

    // MARK: - formatCurrency with AppConfig

    @Test("Format USD amount")
    func testFormatUSD() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = config.formatCurrency(1234.56)
        #expect(result.contains("$"))
        #expect(result.contains("1,234.56"))
    }

    @Test("Format VND amount")
    func testFormatVND() {
        var config = AppConfig()
        config.language = "vi"
        config.currency = "VND"
        let result = config.formatCurrency(1500000)
        #expect(result.contains("₫"))
        #expect(result.contains("1.500.000"))
    }

    @Test("Format JPY amount")
    func testFormatJPY() {
        let config = AppConfig(language: "ja", currency: "JPY")
        let result = config.formatCurrency(15000)
        #expect(result.contains("¥"))
        #expect(result.contains("15,000"))
    }

    @Test("Format EUR amount")
    func testFormatEUR() {
        let config = AppConfig(language: "en", currency: "EUR")
        let result = config.formatCurrency(1234.56)
        #expect(result.contains("€"))
        #expect(result.contains("1,234.56"))
    }

    @Test("Format with explicit currency and language via init")
    func testFormatExplicit() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = config.formatCurrency(1000)
        #expect(result.contains("$"))
        #expect(result.contains("1,000.00"))
    }

    @Test("Format VND with period separators")
    func testFormatVNDExplicit() {
        let config = AppConfig(language: "vi", currency: "VND")
        let result = config.formatCurrency(500000)
        #expect(result.contains("500.000"))
    }

    // MARK: - formatNumber (without symbol)

    @Test("formatNumber USD")
    func testFormatNumberUSD() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = config.formatNumber(1234.56)
        #expect(result == "1,234.56")
    }

    @Test("formatNumber VND no decimals")
    func testFormatNumberVND() {
        let config = AppConfig(language: "vi", currency: "VND")
        let result = config.formatNumber(1500000)
        #expect(result == "1.500.000")
    }

    @Test("formatNumber JPY no decimals")
    func testFormatNumberJPY() {
        let config = AppConfig(language: "en", currency: "JPY")
        let result = config.formatNumber(15000)
        #expect(result == "15,000")
    }

    @Test("formatNumber KRW no decimals")
    func testFormatNumberKRW() {
        let config = AppConfig(language: "en", currency: "KRW")
        let result = config.formatNumber(50000)
        #expect(result == "50,000")
    }

    @Test("formatNumber with period separator for Vietnamese")
    func testFormatNumberVietnamese() {
        let config = AppConfig(language: "vi", currency: "USD")
        let result = config.formatNumber(1234.56)
        #expect(result == "1.234,56")
    }

    @Test("formatNumber with period separator for Spanish")
    func testFormatNumberSpanish() {
        let config = AppConfig(language: "es", currency: "EUR")
        let result = config.formatNumber(1234.56)
        #expect(result == "1234,56")
    }

    @Test("formatNumber zero amount")
    func testFormatNumberZero() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = config.formatNumber(0)
        #expect(result == "0.00")
    }

    @Test("formatNumber large amount")
    func testFormatNumberLargeAmount() {
        let config = AppConfig(language: "vi", currency: "VND")
        let result = config.formatNumber(999999999)
        #expect(result == "999.999.999")
    }

    @Test("formatNumber small decimal")
    func testFormatNumberSmallDecimal() {
        let config = AppConfig(language: "en", currency: "USD")
        let result = config.formatNumber(0.01)
        #expect(result == "0.01")
    }
}

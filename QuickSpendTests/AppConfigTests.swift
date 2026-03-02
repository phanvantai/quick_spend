import Testing
import Foundation
@testable import QuickSpend

@Suite("AppConfig Tests")
struct AppConfigTests {

    @Test("AppConfig has correct defaults")
    func testDefaults() {
        let config = AppConfig()

        #expect(config.language == "en")
        #expect(config.currency == "USD")
        #expect(config.themeMode == "system")
        #expect(config.isOnboardingComplete == false)
    }

    @Test("AppConfig is Codable")
    func testCodable() throws {
        var config = AppConfig()
        config.language = "vi"
        config.currency = "VND"
        config.themeMode = "dark"
        config.isOnboardingComplete = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded == config)
    }

    @Test("Currency symbol is correct for each currency")
    func testCurrencySymbol() {
        let tests: [(String, String)] = [
            ("USD", "$"),
            ("VND", "d"),
            ("JPY", "¥"),
            ("KRW", "₩"),
            ("THB", "฿"),
            ("EUR", "€"),
        ]

        for (code, expected) in tests {
            var config = AppConfig()
            config.currency = code
            #expect(config.currencySymbol == expected, "Currency \(code) should have symbol \(expected)")
        }
    }

    @Test("currencyUsesDecimals is correct")
    func testCurrencyUsesDecimals() {
        let noDecimals = ["VND", "JPY", "KRW"]
        let withDecimals = ["USD", "EUR", "THB"]

        for code in noDecimals {
            var config = AppConfig()
            config.currency = code
            #expect(config.currencyUsesDecimals == false, "\(code) should not use decimals")
        }

        for code in withDecimals {
            var config = AppConfig()
            config.currency = code
            #expect(config.currencyUsesDecimals == true, "\(code) should use decimals")
        }
    }

    @Test("currencySymbolAfter is correct")
    func testCurrencySymbolAfter() {
        var vnd = AppConfig()
        vnd.currency = "VND"
        #expect(vnd.currencySymbolAfter == true)

        var thb = AppConfig()
        thb.currency = "THB"
        #expect(thb.currencySymbolAfter == true)

        var usd = AppConfig()
        usd.currency = "USD"
        #expect(usd.currencySymbolAfter == false)
    }

    @Test("usesPeriodForThousands only for Vietnamese")
    func testUsesPeriodForThousands() {
        var vi = AppConfig()
        vi.language = "vi"
        #expect(vi.usesPeriodForThousands == true)

        var en = AppConfig()
        en.language = "en"
        #expect(en.usesPeriodForThousands == false)
    }

    @Test("formatCurrency formats correctly for USD")
    func testFormatCurrencyUSD() {
        var config = AppConfig()
        config.currency = "USD"
        config.language = "en"

        let formatted = config.formatCurrency(1234.56)
        #expect(formatted.contains("$"))
        #expect(formatted.contains("1,234.56"))
    }

    @Test("formatCurrency formats correctly for VND")
    func testFormatCurrencyVND() {
        var config = AppConfig()
        config.currency = "VND"
        config.language = "vi"

        let formatted = config.formatCurrency(1500000)
        #expect(formatted.contains("d"))
        #expect(formatted.contains("1.500.000"))
    }

    @Test("languageDisplayName returns correct names")
    func testLanguageDisplayName() {
        var en = AppConfig()
        en.language = "en"
        #expect(en.languageDisplayName == "English")

        var vi = AppConfig()
        vi.language = "vi"
        #expect(vi.languageDisplayName == "Tiếng Việt")
    }

    @Test("colorScheme returns correct values")
    func testColorScheme() {
        var system = AppConfig()
        system.themeMode = "system"
        #expect(system.colorScheme == nil)

        var light = AppConfig()
        light.themeMode = "light"
        #expect(light.colorScheme == .light)

        var dark = AppConfig()
        dark.themeMode = "dark"
        #expect(dark.colorScheme == .dark)
    }

    // MARK: - LanguageOption

    @Test("LanguageOption has exactly 2 options (EN, VI)")
    func testLanguageOptions() {
        let options = LanguageOption.options
        #expect(options.count == 2)
        #expect(options[0].code == "en")
        #expect(options[1].code == "vi")
    }

    @Test("LanguageOption.defaultCurrency maps correctly")
    func testDefaultCurrencyMapping() {
        #expect(LanguageOption.defaultCurrency(for: "en") == "USD")
        #expect(LanguageOption.defaultCurrency(for: "vi") == "VND")
        #expect(LanguageOption.defaultCurrency(for: "unknown") == "USD")
    }

    // MARK: - CurrencyOption

    @Test("CurrencyOption has 6 options")
    func testCurrencyOptions() {
        let options = CurrencyOption.options
        #expect(options.count == 6)

        let codes = options.map(\.code)
        #expect(codes.contains("USD"))
        #expect(codes.contains("VND"))
        #expect(codes.contains("JPY"))
        #expect(codes.contains("KRW"))
        #expect(codes.contains("THB"))
        #expect(codes.contains("EUR"))
    }
}

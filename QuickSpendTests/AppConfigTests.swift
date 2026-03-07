import Testing
import Foundation
import SwiftUI
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
            ("EUR", "€"),
        ]

        for (code, expected) in tests {
            var config = AppConfig()
            config.currency = code
            #expect(config.currencySymbol == expected, "Currency \(code) should have symbol \(expected)")
        }

        // Unknown currencies fall back to the currency code itself
        var krw = AppConfig()
        krw.currency = "KRW"
        #expect(krw.currencySymbol == "KRW")
    }

    @Test("currencyUsesDecimals is correct")
    func testCurrencyUsesDecimals() {
        let noDecimals = ["VND", "JPY"]
        let withDecimals = ["USD", "EUR"]

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

        var usd = AppConfig()
        usd.currency = "USD"
        #expect(usd.currencySymbolAfter == false)

        var eur = AppConfig()
        eur.currency = "EUR"
        #expect(eur.currencySymbolAfter == false)
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

    @Test("LanguageOption has exactly 4 options")
    func testLanguageOptions() {
        let options = LanguageOption.options
        #expect(options.count == 4)
        #expect(options[0].code == "en")
        #expect(options[1].code == "vi")
        #expect(options[2].code == "ja")
        #expect(options[3].code == "es")
    }

    @Test("LanguageOption.defaultCurrency maps correctly")
    func testDefaultCurrencyMapping() {
        #expect(LanguageOption.defaultCurrency(for: "en") == "USD")
        #expect(LanguageOption.defaultCurrency(for: "vi") == "VND")
        #expect(LanguageOption.defaultCurrency(for: "ja") == "JPY")
        #expect(LanguageOption.defaultCurrency(for: "es") == "EUR")
        #expect(LanguageOption.defaultCurrency(for: "unknown") == "USD")
    }

    // MARK: - CurrencyOption

    @Test("CurrencyOption has 4 options")
    func testCurrencyOptions() {
        let options = CurrencyOption.options
        #expect(options.count == 4)

        let codes = options.map(\.code)
        #expect(codes.contains("USD"))
        #expect(codes.contains("VND"))
        #expect(codes.contains("JPY"))
        #expect(codes.contains("EUR"))
    }

    @Test("CurrencyOption.id equals code")
    func testCurrencyOptionId() {
        for option in CurrencyOption.options {
            #expect(option.id == option.code)
        }
    }

    @Test("CurrencyOption symbols match expected values")
    func testCurrencyOptionSymbols() {
        let options = CurrencyOption.options
        let symbolMap = Dictionary(uniqueKeysWithValues: options.map { ($0.code, $0.symbol) })
        #expect(symbolMap["USD"] == "$")
        #expect(symbolMap["VND"] == "d")
        #expect(symbolMap["JPY"] == "¥")
        #expect(symbolMap["EUR"] == "€")
    }

    // MARK: - LanguageOption ID

    @Test("LanguageOption.id equals code")
    func testLanguageOptionId() {
        for option in LanguageOption.options {
            #expect(option.id == option.code)
        }
    }

    @Test("LanguageOption has flags and country codes")
    func testLanguageOptionFields() {
        for option in LanguageOption.options {
            #expect(!option.flag.isEmpty)
            #expect(!option.countryCode.isEmpty)
            #expect(!option.displayName.isEmpty)
        }
    }

    // MARK: - ThemeOption

    @Test("ThemeOption.options returns 3 options for English")
    func testThemeOptionsCount() {
        let options = ThemeOption.options(language: "en")
        #expect(options.count == 3)
    }

    @Test("ThemeOption codes are system, light, dark")
    func testThemeOptionCodes() {
        let options = ThemeOption.options(language: "en")
        let codes = options.map(\.code)
        #expect(codes == ["system", "light", "dark"])
    }

    @Test("ThemeOption.id equals code")
    func testThemeOptionId() {
        let options = ThemeOption.options(language: "en")
        for option in options {
            #expect(option.id == option.code)
        }
    }

    @Test("ThemeOption has non-empty titles and icons")
    func testThemeOptionTitlesAndIcons() {
        for lang in ["en", "vi", "ja", "es"] {
            let options = ThemeOption.options(language: lang)
            for option in options {
                #expect(!option.title.isEmpty, "ThemeOption \(option.code) has empty title for \(lang)")
                #expect(!option.icon.isEmpty, "ThemeOption \(option.code) has empty icon for \(lang)")
            }
        }
    }

    @Test("ThemeOption icons are correct SF Symbols")
    func testThemeOptionIcons() {
        let options = ThemeOption.options(language: "en")
        #expect(options[0].icon == "circle.lefthalf.filled")
        #expect(options[1].icon == "sun.max.fill")
        #expect(options[2].icon == "moon.fill")
    }

    // MARK: - Additional AppConfig coverage

    @Test("languageDisplayName for Japanese")
    func testLanguageDisplayNameJapanese() {
        var config = AppConfig()
        config.language = "ja"
        #expect(config.languageDisplayName == "日本語")
    }

    @Test("languageDisplayName for Spanish")
    func testLanguageDisplayNameSpanish() {
        var config = AppConfig()
        config.language = "es"
        #expect(config.languageDisplayName == "Español")
    }

    @Test("languageDisplayName for unknown language falls back to code")
    func testLanguageDisplayNameUnknown() {
        var config = AppConfig()
        config.language = "zz"
        #expect(config.languageDisplayName == "zz")
    }

    @Test("usesPeriodForThousands is true for Spanish")
    func testUsesPeriodForThousandsSpanish() {
        var config = AppConfig()
        config.language = "es"
        #expect(config.usesPeriodForThousands == true)
    }

    @Test("usesPeriodForThousands is false for Japanese")
    func testUsesPeriodForThousandsJapanese() {
        var config = AppConfig()
        config.language = "ja"
        #expect(config.usesPeriodForThousands == false)
    }

    @Test("formatCurrency for JPY has no decimals")
    func testFormatCurrencyJPY() {
        var config = AppConfig()
        config.currency = "JPY"
        config.language = "en"

        let formatted = config.formatCurrency(1500)
        #expect(formatted.contains("¥"))
        #expect(formatted.contains("1,500"))
        #expect(!formatted.contains("."))
    }

    @Test("formatCurrency for EUR with English language")
    func testFormatCurrencyEUR() {
        var config = AppConfig()
        config.currency = "EUR"
        config.language = "en"

        let formatted = config.formatCurrency(1234.56)
        #expect(formatted.contains("€"))
        #expect(formatted.contains("1,234.56"))
    }

    @Test("formatCurrency for EUR with Spanish language uses period separator")
    func testFormatCurrencyEURSpanish() {
        var config = AppConfig()
        config.currency = "EUR"
        config.language = "es"

        let formatted = config.formatCurrency(1234.56)
        #expect(formatted.contains("€"))
        #expect(formatted.contains("1.234,56"))
    }

    @Test("AppConfig Equatable conformance")
    func testEquatable() {
        let config1 = AppConfig()
        var config2 = AppConfig()
        #expect(config1 == config2)

        config2.language = "vi"
        #expect(config1 != config2)
    }
}

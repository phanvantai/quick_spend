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
        #expect(config.hasSeenBalanceWhatsNew == false)
    }

    @Test("Forward-compat decode — v2.4 JSON without hasSeenBalanceWhatsNew decodes to false (so the modal fires once for existing users)")
    func testForwardCompatDecodeFromV24Json() throws {
        // Realistic v2.4 payload as it would have been written before the field existed
        let v24Json = """
        {
            "language": "vi",
            "currency": "VND",
            "themeMode": "dark",
            "isOnboardingComplete": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppConfig.self, from: v24Json)

        #expect(decoded.language == "vi")
        #expect(decoded.currency == "VND")
        #expect(decoded.themeMode == "dark")
        #expect(decoded.isOnboardingComplete == true)
        // The whole point: missing field decodes to false, not a thrown error.
        #expect(decoded.hasSeenBalanceWhatsNew == false)
    }

    @Test("Forward-compat decode — empty JSON object decodes to full defaults")
    func testForwardCompatDecodeFromEmptyJson() throws {
        let emptyJson = "{}".data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppConfig.self, from: emptyJson)

        #expect(decoded == AppConfig())
    }

    @Test("formatAmountInput preserves a leading minus so overdrawn users can type a negative opening balance")
    func testFormatAmountInputAllowsNegativeEnglish() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.formatAmountInput("-") == "-")
        #expect(config.formatAmountInput("-100") == "-100")
        #expect(config.formatAmountInput("-1234567") == "-1,234,567")
        #expect(config.formatAmountInput("-1234.56") == "-1,234.56")
    }

    @Test("formatAmountInput preserves a leading minus with VND grouping (period thousands)")
    func testFormatAmountInputAllowsNegativeVietnamese() {
        var config = AppConfig()
        config.language = "vi"

        #expect(config.formatAmountInput("-1234567") == "-1.234.567")
    }

    @Test("parseAmount handles negative inputs across all locales")
    func testParseAmountNegative() {
        for lang in ["en", "vi", "ja", "es"] {
            var config = AppConfig()
            config.language = lang
            let formatted = config.formatAmountInput("-50000")
            #expect(config.parseAmount(formatted) == -50_000, "lang=\(lang)")
        }
    }

    @Test("Codable roundtrip preserves hasSeenBalanceWhatsNew=true")
    func testRoundtripPreservesHasSeenBalanceWhatsNew() throws {
        var config = AppConfig()
        config.hasSeenBalanceWhatsNew = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.hasSeenBalanceWhatsNew == true)
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
            ("VND", "₫"),
            ("JPY", "¥"),
            ("EUR", "€"),
        ]

        for (code, expected) in tests {
            var config = AppConfig()
            config.currency = code
            #expect(config.currencySymbol.contains(expected), "Currency \(code) should contain symbol \(expected)")
        }
    }

    @Test("currencyLocale maps language to correct locale")
    func testCurrencyLocale() {
        let tests: [(String, String)] = [
            ("en", "en_US"),
            ("vi", "vi_VN"),
            ("ja", "ja_JP"),
            ("es", "es_ES"),
        ]

        for (lang, expectedId) in tests {
            var config = AppConfig()
            config.language = lang
            #expect(config.currencyLocale.identifier == expectedId, "Language \(lang) should map to \(expectedId)")
        }
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
        #expect(formatted.contains("₫"))
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
        #expect(symbolMap["VND"] == "₫")
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

    @Test("formatCurrency for EUR with Spanish language uses correct locale formatting")
    func testFormatCurrencyEURSpanish() {
        var config = AppConfig()
        config.currency = "EUR"
        config.language = "es"

        let formatted = config.formatCurrency(1234.56)
        #expect(formatted.contains("€"))
        #expect(formatted.contains("1234,56"))
    }

    @Test("AppConfig Equatable conformance")
    func testEquatable() {
        let config1 = AppConfig()
        var config2 = AppConfig()
        #expect(config1 == config2)

        config2.language = "vi"
        #expect(config1 != config2)
    }

    // MARK: - Speech Language

    @Test("speechLanguage defaults to nil")
    func testSpeechLanguageDefault() {
        let config = AppConfig()
        #expect(config.speechLanguage == nil)
    }

    @Test("effectiveSpeechLanguage falls back to app language when nil")
    func testEffectiveSpeechLanguageFallback() {
        var config = AppConfig()
        config.language = "vi"
        config.speechLanguage = nil
        #expect(config.effectiveSpeechLanguage == "vi")
    }

    @Test("effectiveSpeechLanguage returns explicit value when set")
    func testEffectiveSpeechLanguageExplicit() {
        var config = AppConfig()
        config.language = "en"
        config.speechLanguage = "es"
        #expect(config.effectiveSpeechLanguage == "es")
    }

    @Test("speechLanguageDisplayName matches effectiveSpeechLanguage")
    func testSpeechLanguageDisplayName() {
        var config = AppConfig()
        config.language = "en"
        config.speechLanguage = "ja"
        #expect(config.speechLanguageDisplayName == "日本語")
    }

    @Test("speechLanguageDisplayName falls back to app language display name")
    func testSpeechLanguageDisplayNameFallback() {
        var config = AppConfig()
        config.language = "vi"
        config.speechLanguage = nil
        #expect(config.speechLanguageDisplayName == "Tiếng Việt")
    }

    @Test("speechLanguage survives Codable round-trip")
    func testSpeechLanguageCodable() throws {
        var config = AppConfig()
        config.speechLanguage = "ja"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.speechLanguage == "ja")
    }

    @Test("speechLanguage nil survives Codable round-trip")
    func testSpeechLanguageNilCodable() throws {
        var config = AppConfig()
        config.speechLanguage = nil

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.speechLanguage == nil)
        #expect(decoded.effectiveSpeechLanguage == "en")
    }

    @Test("Decoding old config without speechLanguage field defaults to nil")
    func testBackwardCompatibility() throws {
        let json = """
        {"language":"vi","currency":"VND","themeMode":"dark","isOnboardingComplete":true}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        #expect(decoded.speechLanguage == nil)
        #expect(decoded.effectiveSpeechLanguage == "vi")
    }

    // MARK: - parseAmount

    @Test("parseAmount with English locale parses decimal point correctly")
    func testParseAmountEnglishDecimal() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.parseAmount("12.5") == 12.5)
        #expect(config.parseAmount("12.50") == 12.5)
        #expect(config.parseAmount("0.99") == 0.99)
    }

    @Test("parseAmount with English locale strips comma thousands separator")
    func testParseAmountEnglishThousands() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.parseAmount("1,234") == 1234)
        #expect(config.parseAmount("1,234.56") == 1234.56)
        #expect(config.parseAmount("1,000,000") == 1_000_000)
    }

    @Test("parseAmount with English locale handles plain integers")
    func testParseAmountEnglishInteger() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.parseAmount("125") == 125)
        #expect(config.parseAmount("0") == 0)
    }

    @Test("parseAmount with Vietnamese locale parses comma decimal correctly")
    func testParseAmountVietnameseDecimal() {
        var config = AppConfig()
        config.language = "vi"

        #expect(config.parseAmount("12,5") == 12.5)
        #expect(config.parseAmount("12,50") == 12.5)
    }

    @Test("parseAmount with Vietnamese locale strips period thousands separator")
    func testParseAmountVietnameseThousands() {
        var config = AppConfig()
        config.language = "vi"

        #expect(config.parseAmount("1.234") == 1234)
        #expect(config.parseAmount("1.234,56") == 1234.56)
        #expect(config.parseAmount("1.000.000") == 1_000_000)
    }

    @Test("parseAmount with Spanish locale uses comma as decimal separator")
    func testParseAmountSpanishDecimal() {
        var config = AppConfig()
        config.language = "es"

        #expect(config.parseAmount("12,5") == 12.5)
        #expect(config.parseAmount("1.234,56") == 1234.56)
    }

    @Test("parseAmount with Japanese locale uses period as decimal separator")
    func testParseAmountJapaneseDecimal() {
        var config = AppConfig()
        config.language = "ja"

        #expect(config.parseAmount("12.5") == 12.5)
        #expect(config.parseAmount("1,234") == 1234)
    }

    @Test("parseAmount returns nil for empty or whitespace-only input")
    func testParseAmountEmpty() {
        let config = AppConfig()

        #expect(config.parseAmount("") == nil)
        #expect(config.parseAmount("   ") == nil)
    }

    @Test("parseAmount returns nil for non-numeric input")
    func testParseAmountNonNumeric() {
        let config = AppConfig()

        #expect(config.parseAmount("abc") == nil)
        #expect(config.parseAmount("$12") == nil)
    }

    @Test("parseAmount trims whitespace before parsing")
    func testParseAmountTrimsWhitespace() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.parseAmount("  12.5  ") == 12.5)
        #expect(config.parseAmount(" 1,234 ") == 1234)
    }

    // MARK: - formatAmountInput

    @Test("formatAmountInput adds comma grouping for English")
    func testFormatAmountInputEnglish() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.formatAmountInput("1234") == "1,234")
        #expect(config.formatAmountInput("1500000") == "1,500,000")
        #expect(config.formatAmountInput("123") == "123")
        #expect(config.formatAmountInput("1234.56") == "1,234.56")
    }

    @Test("formatAmountInput adds period grouping for Vietnamese")
    func testFormatAmountInputVietnamese() {
        var config = AppConfig()
        config.language = "vi"

        #expect(config.formatAmountInput("1234") == "1.234")
        #expect(config.formatAmountInput("1500000") == "1.500.000")
        #expect(config.formatAmountInput("1234,56") == "1.234,56")
    }

    @Test("formatAmountInput adds period grouping for Spanish")
    func testFormatAmountInputSpanish() {
        var config = AppConfig()
        config.language = "es"

        #expect(config.formatAmountInput("1234,56") == "1.234,56")
        #expect(config.formatAmountInput("1500000") == "1.500.000")
    }

    @Test("formatAmountInput handles edge cases")
    func testFormatAmountInputEdgeCases() {
        var config = AppConfig()
        config.language = "en"

        #expect(config.formatAmountInput("") == "")
        #expect(config.formatAmountInput("0") == "0")
        #expect(config.formatAmountInput("0.99") == "0.99")
        #expect(config.formatAmountInput("12.") == "12.")
        #expect(config.formatAmountInput("0000123") == "123")
    }

    @Test("formatAmountInput is idempotent with already-formatted input")
    func testFormatAmountInputIdempotent() {
        var config = AppConfig()
        config.language = "en"

        let formatted = config.formatAmountInput("1234567")
        #expect(formatted == "1,234,567")
        // Re-formatting should produce the same result
        #expect(config.formatAmountInput(formatted) == "1,234,567")
    }

    @Test("formatAmountInput round-trips with parseAmount")
    func testFormatAmountInputParseRoundTrip() {
        var config = AppConfig()
        config.language = "en"

        let formatted = config.formatAmountInput("1234.56")
        #expect(formatted == "1,234.56")
        #expect(config.parseAmount(formatted) == 1234.56)

        config.language = "vi"
        let formattedVi = config.formatAmountInput("1234,56")
        #expect(formattedVi == "1.234,56")
        #expect(config.parseAmount(formattedVi) == 1234.56)
    }
}

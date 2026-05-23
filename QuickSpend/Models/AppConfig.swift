import Foundation
import SwiftUI

/// App configuration model for user preferences
/// Stored in UserDefaults as JSON
struct AppConfig: Codable, Equatable {
    var language: String = "en"
    var currency: String = "USD"
    var themeMode: String = "system"   // "light", "dark", "system"
    var isOnboardingComplete: Bool = false
    /// Whether the user has dismissed the one-time WhatsNew modal that introduces the
    /// Account Balance feature. Set atomically with `isOnboardingComplete` on fresh
    /// installs so they never see the modal (the onboarding step already covers setup).
    /// Existing users upgrading from v2.4 have no such field in their saved JSON, so
    /// the forward-compat decoder defaults this to `false` and the modal fires once.
    var hasSeenBalanceWhatsNew: Bool = false
    /// Whether the user has dismissed the one-time modal that teaches the Siri
    /// "Hey Siri, …" trigger phrases. Fires AFTER the Balance modal and BEFORE
    /// the Voice Shortcut promo, since Siri works out of the box and the
    /// shortcut is an upgrade on top.
    var hasSeenSiriPromo: Bool = false
    /// Whether the user has dismissed the one-time WhatsNew modal that introduces the
    /// Siri/Shortcuts voice expense feature. Unlike the Balance modal, this is NOT
    /// auto-flipped during onboarding — fresh installs and upgrades both see it once
    /// because it's an opt-in feature that lives outside the app.
    var hasSeenVoiceShortcutPromo: Bool = false
    /// The Home FocalChartCard's currently selected view — "donut" (by category)
    /// or "bar" (income vs expense). Persisted so the user's pick survives app
    /// relaunch. Unknown values from older builds decode to "donut".
    var focalChartPreference: String = FocalChartPreference.donut.rawValue

    /// Convenience init used by previews and on-the-fly currency formatting in views.
    /// All params default to the same values as the stored properties, so `AppConfig()`
    /// still works as a struct-default initializer.
    init(language: String = "en", currency: String = "USD") {
        self.language = language
        self.currency = currency
    }

    /// Forward-compat decoder: every field uses `decodeIfPresent` with the struct
    /// default as fallback. New optional fields added in future versions will decode
    /// to their defaults when reading older saved JSON, instead of throwing and
    /// silently wiping the user's saved preferences via the catch in
    /// `PreferencesService.getConfig()`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
        self.currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "USD"
        self.themeMode = try c.decodeIfPresent(String.self, forKey: .themeMode) ?? "system"
        self.isOnboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .isOnboardingComplete) ?? false
        self.hasSeenBalanceWhatsNew = try c.decodeIfPresent(Bool.self, forKey: .hasSeenBalanceWhatsNew) ?? false
        self.hasSeenSiriPromo = try c.decodeIfPresent(Bool.self, forKey: .hasSeenSiriPromo) ?? false
        self.hasSeenVoiceShortcutPromo = try c.decodeIfPresent(Bool.self, forKey: .hasSeenVoiceShortcutPromo) ?? false
        let storedFocal = try c.decodeIfPresent(String.self, forKey: .focalChartPreference)
        self.focalChartPreference = FocalChartPreference(rawValue: storedFocal ?? "")?.rawValue
            ?? FocalChartPreference.donut.rawValue
    }

    // MARK: - Currency

    /// Locale used for currency formatting, derived from the user's language.
    var currencyLocale: Locale {
        Locale(identifier: Self.localeIdentifier(for: language))
    }

    /// Canonical locale identifier for a given language code.
    /// Used for both currency formatting and speech recognition.
    static func localeIdentifier(for language: String) -> String {
        switch language {
        case "vi": return "vi_VN"
        case "ja": return "ja_JP"
        case "es": return "es_ES"
        default:   return "en_US"
        }
    }

    /// The currency symbol for the current locale and currency code.
    var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = currencyLocale
        return formatter.currencySymbol
    }

    /// Format a currency amount using locale-aware formatting.
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = currencyLocale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Format amount without currency symbol (just the number with locale separators).
    func formatNumber(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = currencyLocale
        formatter.currencySymbol = ""
        let result = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return result.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .init(charactersIn: "\u{00A0}"))
    }

    // MARK: - Amount Parsing

    /// Parse an amount string respecting the current language's decimal/thousands separators.
    /// For example, English uses "," for thousands and "." for decimals (1,234.56),
    /// while Vietnamese/Spanish use "." for thousands and "," for decimals (1.234,56).
    func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let usesPeriodForThousands = (language == "vi" || language == "es")

        if usesPeriodForThousands {
            // vi/es: "." is thousands separator, "," is decimal separator
            let cleaned = trimmed
                .replacingOccurrences(of: ".", with: "")   // strip thousands separator
                .replacingOccurrences(of: ",", with: ".")  // convert decimal separator to "."
                .replacingOccurrences(of: " ", with: "")
            return Double(cleaned)
        } else {
            // en/ja: "," is thousands separator, "." is decimal separator
            let cleaned = trimmed
                .replacingOccurrences(of: ",", with: "")   // strip thousands separator
                .replacingOccurrences(of: " ", with: "")
            return Double(cleaned)
        }
    }

    // MARK: - Live Amount Formatting

    /// Format raw keyboard input with locale-appropriate grouping separators as the user types.
    /// Accepts digits, the locale's decimal separator ("." for en/ja, "," for vi/es),
    /// and a leading "-" sign so users with an overdrawn account can enter a
    /// negative opening balance.
    func formatAmountInput(_ text: String) -> String {
        let usesPeriodForThousands = (language == "vi" || language == "es")
        let decimalSep: Character = usesPeriodForThousands ? "," : "."
        let thousandsSep: Character = usesPeriodForThousands ? "." : ","

        // Preserve a single leading minus sign — the rest of the formatter only
        // sees the magnitude.
        let isNegative = text.hasPrefix("-")
        let withoutSign = isNegative ? String(text.dropFirst()) : text

        // Strip everything except digits and the locale-appropriate decimal separator
        var digits = String(withoutSign.filter { $0.isNumber || $0 == decimalSep })

        // Ensure at most one decimal separator
        if let first = digits.firstIndex(of: decimalSep) {
            let rest = digits[digits.index(after: first)...].filter { $0 != decimalSep }
            digits = String(digits[...first]) + rest
        }

        // Split into integer and decimal parts
        let parts = digits.split(separator: decimalSep, maxSplits: 1, omittingEmptySubsequences: false)
        var integerPart = String(parts.first ?? "")
        let decimalPart = parts.count > 1 ? String(parts[1]) : nil

        // Remove leading zeros (but keep at least one "0")
        integerPart = String(integerPart.drop(while: { $0 == "0" }))
        if integerPart.isEmpty { integerPart = digits.contains(decimalSep) || !withoutSign.isEmpty ? "0" : "" }

        // Guard empty — if only "-" was typed, surface it so the user sees the
        // sign as they continue to type.
        if integerPart.isEmpty && decimalPart == nil {
            return isNegative ? "-" : ""
        }

        // Insert thousands separators
        var result = ""
        for (i, char) in integerPart.reversed().enumerated() {
            if i > 0 && i % 3 == 0 {
                result.append(thousandsSep)
            }
            result.append(char)
        }
        result = String(result.reversed())

        // Append decimal part
        if let dec = decimalPart {
            result.append(decimalSep)
            result.append(contentsOf: dec)
        }

        return isNegative ? "-" + result : result
    }

    // MARK: - Language

    var languageDisplayName: String {
        Self.displayName(for: language)
    }

    static func displayName(for code: String) -> String {
        switch code {
        case "vi": return "Tiếng Việt"
        case "ja": return "日本語"
        case "es": return "Español"
        case "en": return "English"
        default: return code
        }
    }

    // MARK: - Theme

    var colorScheme: ColorScheme? {
        switch themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }
}

// MARK: - Focal Chart Preference

/// The Home screen's FocalChartCard supports two views; the user's choice is
/// persisted via `AppConfig.focalChartPreference`. New chart types added later
/// can extend this enum; unknown raw values decode safely to `.donut`.
enum FocalChartPreference: String, CaseIterable {
    case donut
    case bar
}

// MARK: - Language Option

struct LanguageOption: Identifiable {
    let code: String
    let countryCode: String
    let displayName: String
    let flag: String
    let defaultCurrency: String

    var id: String { code }

    static let options: [LanguageOption] = [
        LanguageOption(code: "en", countryCode: "US", displayName: "English", flag: "🇺🇸", defaultCurrency: "USD"),
        LanguageOption(code: "vi", countryCode: "VN", displayName: "Tiếng Việt", flag: "🇻🇳", defaultCurrency: "VND"),
        LanguageOption(code: "ja", countryCode: "JP", displayName: "日本語", flag: "🇯🇵", defaultCurrency: "JPY"),
        LanguageOption(code: "es", countryCode: "ES", displayName: "Español", flag: "🇪🇸", defaultCurrency: "EUR"),
    ]

    static func defaultCurrency(for languageCode: String) -> String {
        options.first { $0.code == languageCode }?.defaultCurrency ?? "USD"
    }
}

// MARK: - Currency Option

struct CurrencyOption: Identifiable {
    let code: String
    let symbol: String

    var id: String { code }

    static let options: [CurrencyOption] = [
        CurrencyOption(code: "USD", symbol: "$"),
        CurrencyOption(code: "VND", symbol: "₫"),
        CurrencyOption(code: "JPY", symbol: "¥"),
        CurrencyOption(code: "EUR", symbol: "€"),
    ]
}

// MARK: - Theme Option

struct ThemeOption: Identifiable {
    let code: String
    let icon: String
    let title: String

    var id: String { code }

    static func options(language: String) -> [ThemeOption] {
        [
            ThemeOption(code: "system", icon: "circle.lefthalf.filled", title: L10n.tr("settings.theme_system", language)),
            ThemeOption(code: "light", icon: "sun.max.fill", title: L10n.tr("settings.theme_light", language)),
            ThemeOption(code: "dark", icon: "moon.fill", title: L10n.tr("settings.theme_dark", language)),
        ]
    }
}

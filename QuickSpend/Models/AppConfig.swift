import Foundation
import SwiftUI

/// App configuration model for user preferences
/// Stored in UserDefaults as JSON
struct AppConfig: Codable, Equatable {
    var language: String = "en"
    var speechLanguage: String?  // nil = same as app language
    var currency: String = "USD"
    var themeMode: String = "system"   // "light", "dark", "system"
    var isOnboardingComplete: Bool = false

    /// The language used for speech recognition and AI parsing.
    /// Falls back to app language when not explicitly set.
    var effectiveSpeechLanguage: String {
        speechLanguage ?? language
    }

    // MARK: - Currency

    var currencySymbol: String {
        switch currency {
        case "VND": return "d"
        case "USD": return "$"
        case "JPY": return "¥"
        case "EUR": return "€"
        default: return currency
        }
    }

    /// Whether this currency uses decimal places
    var currencyUsesDecimals: Bool {
        currency != "VND" && currency != "JPY"
    }

    /// Whether the currency symbol goes after the amount
    var currencySymbolAfter: Bool {
        currency == "VND"
    }

    /// Whether to use period as thousand separator
    var usesPeriodForThousands: Bool {
        language == "vi" || language == "es"
    }

    /// Format a currency amount with proper symbol placement and number formatting
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = currencyUsesDecimals ? 2 : 0
        formatter.maximumFractionDigits = currencyUsesDecimals ? 2 : 0

        if usesPeriodForThousands {
            formatter.groupingSeparator = "."
            formatter.decimalSeparator = ","
        } else {
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
        }

        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"

        if currencySymbolAfter {
            return "\(formatted) \(currencySymbol)"
        } else {
            return "\(currencySymbol)\(formatted)"
        }
    }

    // MARK: - Language

    var languageDisplayName: String {
        Self.displayName(for: language)
    }

    var speechLanguageDisplayName: String {
        Self.displayName(for: effectiveSpeechLanguage)
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
        CurrencyOption(code: "VND", symbol: "d"),
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

import Foundation
import SwiftUI

/// App configuration model for user preferences
/// Stored in UserDefaults as JSON
struct AppConfig: Codable, Equatable {
    var language: String = "en"
    var currency: String = "USD"
    var themeMode: String = "system"   // "light", "dark", "system"
    var isOnboardingComplete: Bool = false

    // MARK: - Currency

    var currencySymbol: String {
        switch currency {
        case "VND": return "d"
        case "USD": return "$"
        case "JPY": return "¥"
        case "KRW": return "₩"
        case "THB": return "฿"
        case "EUR": return "€"
        default: return currency
        }
    }

    /// Whether this currency uses decimal places
    var currencyUsesDecimals: Bool {
        currency != "VND" && currency != "JPY" && currency != "KRW"
    }

    /// Whether the currency symbol goes after the amount
    var currencySymbolAfter: Bool {
        currency == "VND" || currency == "THB"
    }

    /// Whether to use period as thousand separator
    var usesPeriodForThousands: Bool {
        language == "vi"
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
        switch language {
        case "vi": return "Tiếng Việt"
        case "en": return "English"
        default: return language
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
        CurrencyOption(code: "KRW", symbol: "₩"),
        CurrencyOption(code: "THB", symbol: "฿"),
        CurrencyOption(code: "EUR", symbol: "€"),
    ]
}

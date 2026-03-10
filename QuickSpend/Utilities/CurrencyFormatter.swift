import Foundation

/// Currency formatting utility
/// Handles locale-aware number formatting with proper symbol placement
enum CurrencyFormatter {

    /// Format an amount using the given app config settings
    static func format(_ amount: Double, config: AppConfig) -> String {
        config.formatCurrency(amount)
    }

    /// Format an amount with explicit currency and language
    static func format(_ amount: Double, currency: String, language: String) -> String {
        let config = AppConfig(language: language, currency: currency)
        return config.formatCurrency(amount)
    }

    /// Format amount without currency symbol (just the number)
    static func formatNumber(_ amount: Double, currency: String, language: String) -> String {
        let config = AppConfig(language: language, currency: currency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = config.currencyLocale
        formatter.currencySymbol = ""
        let result = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        // Trim any leftover whitespace or non-breaking spaces from empty symbol
        return result.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .init(charactersIn: "\u{00A0}"))
    }
}

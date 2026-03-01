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
        let usesDecimals = currency != "VND" && currency != "JPY" && currency != "KRW"
        let usesPeriodForThousands = language == "vi" || language == "es"

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = usesDecimals ? 2 : 0
        formatter.maximumFractionDigits = usesDecimals ? 2 : 0

        if usesPeriodForThousands {
            formatter.groupingSeparator = "."
            formatter.decimalSeparator = ","
        } else {
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
        }

        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

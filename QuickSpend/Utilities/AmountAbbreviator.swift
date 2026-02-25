import Foundation

/// Locale-aware amount abbreviation (e.g., "8.1 Tr" for VND, "8.1M" for USD)
enum AmountAbbreviator {

    static func abbreviate(_ amount: Double, currency: String, language: String) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""

        switch currency {
        case "VND":
            if absAmount >= 1_000_000_000 {
                return "\(sign)\(formatDecimal(absAmount / 1_000_000_000)) T"
            } else if absAmount >= 1_000_000 {
                return "\(sign)\(formatDecimal(absAmount / 1_000_000)) Tr"
            } else if absAmount >= 1_000 {
                return "\(sign)\(formatDecimal(absAmount / 1_000)) K"
            }
            return "\(sign)\(Int(absAmount))"

        case "JPY":
            if absAmount >= 100_000_000 {
                return "\(sign)\(formatDecimal(absAmount / 100_000_000))億"
            } else if absAmount >= 10_000 {
                return "\(sign)\(formatDecimal(absAmount / 10_000))万"
            }
            return "\(sign)\(Int(absAmount))"

        case "KRW":
            if absAmount >= 100_000_000 {
                return "\(sign)\(formatDecimal(absAmount / 100_000_000))억"
            } else if absAmount >= 10_000 {
                return "\(sign)\(formatDecimal(absAmount / 10_000))만"
            }
            return "\(sign)\(Int(absAmount))"

        default: // USD, EUR, THB
            if absAmount >= 1_000_000 {
                return "\(sign)\(formatDecimal(absAmount / 1_000_000))M"
            } else if absAmount >= 1_000 {
                return "\(sign)\(formatDecimal(absAmount / 1_000))K"
            }
            return "\(sign)\(formatDecimal(absAmount))"
        }
    }

    private static func formatDecimal(_ value: Double) -> String {
        if value == value.rounded(.down) {
            return String(format: "%.0f", value)
        }
        let formatted = String(format: "%.1f", value)
        // Remove trailing zero after decimal (e.g., "8.0" -> "8")
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }
}

import Foundation

/// Month formatting utilities for the home dashboard.
/// For general localized strings, use L10n.tr() directly.
enum HomeStrings {

    /// Month abbreviation (e.g., "T1" for Vietnamese, "Jan" for English)
    static func monthAbbreviation(for date: Date, language: String, showYear: Bool = false) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        let label: String
        switch language {
        case "vi":
            label = "T\(month)"
        case "ja":
            label = "\(month)月"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: language)
            formatter.dateFormat = "MMM"
            label = formatter.string(from: date)
        }

        if showYear {
            return "\(label)/\(year)"
        }
        return label
    }

    /// Format month label for app bar (e.g., "Tháng 1, 2026")
    static func monthLabel(for date: Date, language: String) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        switch language {
        case "vi":
            return "Tháng \(month), \(year)"
        case "ja":
            return "\(year)年\(month)月"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: language)
            formatter.dateFormat = "MMMM, yyyy"
            return formatter.string(from: date)
        }
    }
}

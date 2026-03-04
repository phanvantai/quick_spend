import Foundation

/// Localized UI strings for the home dashboard
enum HomeStrings {

    static func overviewTitle(_ lang: String) -> String {
        L10n.tr("home.overview_title", lang)
    }

    static func balance(_ lang: String) -> String {
        L10n.tr("common.balance", lang)
    }

    static func expense(_ lang: String) -> String {
        L10n.tr("common.expense", lang)
    }

    static func income(_ lang: String) -> String {
        L10n.tr("common.income", lang)
    }

    static func reportTitle(_ lang: String) -> String {
        L10n.tr("home.report_title", lang)
    }

    static func spent(_ lang: String) -> String {
        L10n.tr("home.spent", lang)
    }

    static func earned(_ lang: String) -> String {
        L10n.tr("home.earned", lang)
    }

    static func viewDetailedReport(_ lang: String) -> String {
        L10n.tr("home.view_detailed_report", lang)
    }

    static func trendsTitle(_ lang: String) -> String {
        L10n.tr("home.trends_title", lang)
    }

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

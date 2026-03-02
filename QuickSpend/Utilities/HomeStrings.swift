import Foundation

/// Localized UI strings for the home dashboard (EN/VI only)
enum HomeStrings {

    static func overviewTitle(_ lang: String) -> String {
        lang == "vi" ? "Tổng quan thu chi" : "Income & Expense Overview"
    }

    static func balance(_ lang: String) -> String {
        lang == "vi" ? "Khoản dư" : "Balance"
    }

    static func expense(_ lang: String) -> String {
        lang == "vi" ? "Chi tiêu" : "Expense"
    }

    static func income(_ lang: String) -> String {
        lang == "vi" ? "Thu nhập" : "Income"
    }

    static func reportTitle(_ lang: String) -> String {
        lang == "vi" ? "Báo cáo thu chi" : "Income & Expense Report"
    }

    static func spent(_ lang: String) -> String {
        lang == "vi" ? "Đã tiêu" : "Spent"
    }

    static func earned(_ lang: String) -> String {
        lang == "vi" ? "Đã nhận" : "Earned"
    }

    static func viewDetailedReport(_ lang: String) -> String {
        lang == "vi" ? "Xem chi tiết báo cáo" : "View detailed report"
    }

    static func trendsTitle(_ lang: String) -> String {
        lang == "vi" ? "Biến động thu chi" : "Income & Expense Trends"
    }

    /// Month abbreviation (e.g., "T1" for Vietnamese, "Jan" for English)
    static func monthAbbreviation(for date: Date, language: String, showYear: Bool = false) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        let label: String
        if language == "vi" {
            label = "T\(month)"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en")
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

        if language == "vi" {
            return "Tháng \(month), \(year)"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en")
            formatter.dateFormat = "MMMM, yyyy"
            return formatter.string(from: date)
        }
    }
}

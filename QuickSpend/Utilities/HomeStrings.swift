import Foundation

/// Localized UI strings for the home dashboard
enum HomeStrings {

    static func overviewTitle(_ lang: String) -> String {
        switch lang {
        case "vi": return "Tổng quan thu chi"
        case "ja": return "収支概要"
        case "ko": return "수입·지출 개요"
        case "th": return "ภาพรวมรายรับรายจ่าย"
        case "es": return "Resumen financiero"
        default:   return "Income & Expense Overview"
        }
    }

    static func balance(_ lang: String) -> String {
        switch lang {
        case "vi": return "Khoản dư"
        case "ja": return "残高"
        case "ko": return "잔액"
        case "th": return "ยอมคงเหลือ"
        case "es": return "Saldo"
        default:   return "Balance"
        }
    }

    static func expense(_ lang: String) -> String {
        switch lang {
        case "vi": return "Chi tiêu"
        case "ja": return "支出"
        case "ko": return "지출"
        case "th": return "รายจ่าย"
        case "es": return "Gastos"
        default:   return "Expense"
        }
    }

    static func income(_ lang: String) -> String {
        switch lang {
        case "vi": return "Thu nhập"
        case "ja": return "収入"
        case "ko": return "수입"
        case "th": return "รายรับ"
        case "es": return "Ingresos"
        default:   return "Income"
        }
    }

    static func reportTitle(_ lang: String) -> String {
        switch lang {
        case "vi": return "Báo cáo thu chi"
        case "ja": return "収支レポート"
        case "ko": return "수입·지출 보고서"
        case "th": return "รายงานรายรับรายจ่าย"
        case "es": return "Informe financiero"
        default:   return "Income & Expense Report"
        }
    }

    static func spent(_ lang: String) -> String {
        switch lang {
        case "vi": return "Đã tiêu"
        case "ja": return "支出額"
        case "ko": return "지출액"
        case "th": return "ใช้จ่าย"
        case "es": return "Gastado"
        default:   return "Spent"
        }
    }

    static func earned(_ lang: String) -> String {
        switch lang {
        case "vi": return "Đã nhận"
        case "ja": return "収入額"
        case "ko": return "수입액"
        case "th": return "รับ"
        case "es": return "Ganado"
        default:   return "Earned"
        }
    }

    static func viewDetailedReport(_ lang: String) -> String {
        switch lang {
        case "vi": return "Xem chi tiết báo cáo"
        case "ja": return "詳細レポートを見る"
        case "ko": return "상세 보고서 보기"
        case "th": return "ดูรายงานโดยละเอียด"
        case "es": return "Ver informe detallado"
        default:   return "View detailed report"
        }
    }

    static func trendsTitle(_ lang: String) -> String {
        switch lang {
        case "vi": return "Biến động thu chi"
        case "ja": return "収支の推移"
        case "ko": return "수입·지출 추이"
        case "th": return "แนวโน้มรายรับรายจ่าย"
        case "es": return "Tendencias financieras"
        default:   return "Income & Expense Trends"
        }
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
        case "ko":
            label = "\(month)월"
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
        case "vi": return "Tháng \(month), \(year)"
        case "ja": return "\(year)年\(month)月"
        case "ko": return "\(year)년 \(month)월"
        case "th":
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "th")
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        case "es":
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es")
            formatter.dateFormat = "MMMM, yyyy"
            let result = formatter.string(from: date)
            return result.prefix(1).uppercased() + result.dropFirst()
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en")
            formatter.dateFormat = "MMMM, yyyy"
            return formatter.string(from: date)
        }
    }
}

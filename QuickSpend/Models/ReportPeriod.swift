import Foundation

/// Date range options shown in the report period picker. `lastMonth` and
/// `last3Months` require a premium subscription; the picker shows a lock
/// emoji and routes free users to the paywall on selection.
enum ReportPeriod: CaseIterable {
    case thisMonth, lastMonth, last3Months

    func label(language: String) -> String {
        switch self {
        case .thisMonth: return L10n.tr("report.this_month", language)
        case .lastMonth: return L10n.tr("report.last_month", language)
        case .last3Months: return L10n.tr("report.three_months", language)
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .thisMonth: return false
        case .lastMonth, .last3Months: return true
        }
    }

    /// The widest period a user can open. The paywall derives its "Reports"
    /// row from this so it can never promise more than the report screen gives.
    static func longestAvailable(isPremium: Bool) -> ReportPeriod {
        isPremium ? .last3Months : .thisMonth
    }

    static func paywallValue(isPremium: Bool, language: String) -> String {
        longestAvailable(isPremium: isPremium).label(language: language)
    }

    func dateRange(now: Date = Date(), calendar: Calendar = .current) -> (start: Date, end: Date) {
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        switch self {
        case .thisMonth:
            let end = calendar.date(byAdding: .month, value: 1, to: thisMonthStart)!
            return (thisMonthStart, end)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            return (start, thisMonthStart)
        case .last3Months:
            let thisMonthEnd = calendar.date(byAdding: .month, value: 1, to: thisMonthStart)!
            let start = calendar.date(byAdding: .month, value: -3, to: thisMonthEnd)!
            return (start, thisMonthEnd)
        }
    }
}

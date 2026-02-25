import Foundation

/// Data point for the 12-month trend line chart
struct MonthlyTrend: Identifiable {
    let id = UUID()
    let month: Date
    let monthLabel: String
    let totalExpenses: Double
    let totalIncome: Double
}

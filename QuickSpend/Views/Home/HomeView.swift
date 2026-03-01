import SwiftUI
import SwiftData

/// Home dashboard with overview, report, and trends sections
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedMonth = Date()

    // MARK: - Current Month Stats

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var currentStats: PeriodStats {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return PeriodStats.fromTransactions(monthTransactions, startDate: start, endDate: end)
            .withCategoryBreakdown(categories: categories)
    }

    // MARK: - Previous Month Stats (for % change)

    private var previousMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return [] }
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: prevMonth, toGranularity: .month)
        }
    }

    private var previousStats: PeriodStats {
        let calendar = Calendar.current
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else {
            return .empty(startDate: selectedMonth, endDate: selectedMonth)
        }
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: prevMonth))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return PeriodStats.fromTransactions(previousMonthTransactions, startDate: start, endDate: end)
    }

    private var expenseChangePercent: Double {
        computePercentChange(current: currentStats.totalExpenses, previous: previousStats.totalExpenses)
    }

    private var incomeChangePercent: Double {
        computePercentChange(current: currentStats.totalIncome, previous: previousStats.totalIncome)
    }

    // MARK: - Trend Data (12 months)

    private var trendData: [MonthlyTrend] {
        let calendar = Calendar.current
        return (0..<12).map { offset -> MonthlyTrend in
            let month = calendar.date(byAdding: .month, value: -(11 - offset), to: Date())!
            let transactions = allTransactions.filter {
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            let income = transactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let expense = transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }

            let monthNum = calendar.component(.month, from: month)
            let showYear = monthNum == 1 || offset == 0
            let label = HomeStrings.monthAbbreviation(for: month, language: appConfig.language, showYear: showYear)

            return MonthlyTrend(
                month: month,
                monthLabel: label,
                totalExpenses: expense,
                totalIncome: income
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing20) {
                    HomeAppBar(
                        selectedMonth: $selectedMonth,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    OverviewSection(
                        totalExpenses: currentStats.totalExpenses,
                        totalIncome: currentStats.totalIncome,
                        netBalance: currentStats.netBalance,
                        expenseChangePercent: expenseChangePercent,
                        incomeChangePercent: incomeChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    ReportSection(
                        expenseBreakdown: currentStats.expenseCategoryBreakdown,
                        incomeBreakdown: currentStats.incomeCategoryBreakdown,
                        totalExpenses: currentStats.totalExpenses,
                        totalIncome: currentStats.totalIncome,
                        expenseChangePercent: expenseChangePercent,
                        incomeChangePercent: incomeChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    TrendsSection(
                        trendData: trendData,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Helpers

    private func computePercentChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return current > 0 ? 100.0 : 0.0 }
        return ((current - previous) / previous) * 100.0
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}

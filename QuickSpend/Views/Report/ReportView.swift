import SwiftUI
import SwiftData
import Charts

/// Date range options for reports
enum ReportPeriod: CaseIterable {
    case thisMonth, lastMonth, last3Months

    func label(language: String) -> String {
        switch self {
        case .thisMonth: return language == "vi" ? "Tháng này" : "This Month"
        case .lastMonth: return language == "vi" ? "Tháng trước" : "Last Month"
        case .last3Months: return language == "vi" ? "3 tháng" : "3 Months"
        }
    }

    /// Whether this period requires Pro subscription
    var requiresPro: Bool {
        switch self {
        case .thisMonth: return false
        case .lastMonth, .last3Months: return true
        }
    }

    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            return (start, thisMonthStart)
        case .last3Months:
            let thisMonthEnd = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
            let start = calendar.date(byAdding: .month, value: -3, to: thisMonthEnd)!
            return (start, thisMonthEnd)
        }
    }
}

/// Dedicated monthly report screen — donut chart, stats, top expenses, trends
struct ReportView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @State private var showPaywall = false

    private var isVi: Bool { appConfig.language == "vi" }

    // MARK: - Computed Stats

    private var periodRange: (start: Date, end: Date) {
        selectedPeriod.dateRange()
    }

    private var periodTransactions: [Transaction] {
        let range = periodRange
        return allTransactions.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var stats: PeriodStats {
        let range = periodRange
        return PeriodStats.fromTransactions(periodTransactions, startDate: range.start, endDate: range.end)
            .withCategoryBreakdown(categories: categories)
    }

    private var topExpenses: [Transaction] {
        periodTransactions
            .filter(\.isExpense)
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }

    private var daysInPeriod: Int {
        let range = periodRange
        return max(Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1, 1)
    }

    // Trend data: 12 months ending at selected period
    private var trendData: [MonthlyTrend] {
        let calendar = Calendar.current
        let endMonth = periodRange.end
        return (0..<12).map { offset -> MonthlyTrend in
            let month = calendar.date(byAdding: .month, value: -(11 - offset), to: endMonth)!
            let transactions = allTransactions.filter {
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            let income = transactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let expense = transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
            let monthNum = calendar.component(.month, from: month)
            let showYear = monthNum == 1 || offset == 0
            let label = HomeStrings.monthAbbreviation(for: month, language: appConfig.language, showYear: showYear)
            return MonthlyTrend(month: month, monthLabel: label, totalExpenses: expense, totalIncome: income)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing20) {
                periodPicker

                summaryStats

                if !stats.expenseCategoryBreakdown.isEmpty || !stats.incomeCategoryBreakdown.isEmpty {
                    ReportSection(
                        expenseBreakdown: stats.expenseCategoryBreakdown,
                        incomeBreakdown: stats.incomeCategoryBreakdown,
                        totalExpenses: stats.totalExpenses,
                        totalIncome: stats.totalIncome,
                        expenseChangePercent: 0,
                        incomeChangePercent: 0,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )
                }

                if !topExpenses.isEmpty {
                    topExpensesSection
                }

                TrendsSection(
                    trendData: trendData,
                    language: appConfig.language,
                    currency: appConfig.config.currency
                )
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing12)
        }
        .navigationTitle(isVi ? "Báo cáo" : "Report")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onChange(of: selectedPeriod) { _, newPeriod in
            if newPeriod.requiresPro && !subscription.isPro {
                selectedPeriod = .thisMonth
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases, id: \.self) { period in
                if period.requiresPro && !subscription.isPro {
                    Text("\(period.label(language: appConfig.language)) 🔒").tag(period)
                } else {
                    Text(period.label(language: appConfig.language)).tag(period)
                }
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        VStack(spacing: AppTheme.spacing12) {
            // Balance
            HStack {
                Text(isVi ? "Khoản dư" : "Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appConfig.formatCurrency(stats.netBalance))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(stats.netBalance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
            }

            Divider()

            // Income / Expense
            HStack {
                statItem(
                    icon: "arrow.up.circle.fill",
                    color: AppTheme.incomeColor,
                    label: HomeStrings.income(appConfig.language),
                    amount: stats.totalIncome,
                    count: stats.incomeCount
                )
                Spacer()
                statItem(
                    icon: "arrow.down.circle.fill",
                    color: AppTheme.expenseColor,
                    label: HomeStrings.expense(appConfig.language),
                    amount: stats.totalExpenses,
                    count: stats.expenseCount
                )
            }

            Divider()

            // Daily average + Savings rate
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isVi ? "Trung bình/ngày" : "Daily Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appConfig.formatCurrency(stats.totalExpenses / Double(daysInPeriod)))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isVi ? "Tỷ lệ tiết kiệm" : "Savings Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", stats.savingsRate))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(stats.savingsRate >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
                }
            }
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func statItem(icon: String, color: Color, label: String, amount: Double, count: Int) -> some View {
        HStack(spacing: AppTheme.spacing8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appConfig.formatCurrency(amount))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)
                Text(isVi ? "\(count) giao dịch" : "\(count) transactions")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Top Expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(isVi ? "Chi tiêu lớn nhất" : "Top Expenses")
                .font(.headline)

            VStack(spacing: AppTheme.spacing8) {
                ForEach(Array(topExpenses.enumerated()), id: \.element.id) { index, transaction in
                    let category = categories.first { $0.id == transaction.categoryId }
                    HStack(spacing: AppTheme.spacing12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Circle()
                            .fill((category?.color ?? .secondary).opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: category?.iconName ?? "questionmark.circle")
                                    .font(.body)
                                    .foregroundStyle(category?.color ?? .secondary)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.note)
                                .font(.body)
                                .lineLimit(1)
                            Text(category?.name ?? "Other")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(appConfig.formatCurrency(transaction.amount))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.expenseColor)
                    }
                    .padding(.vertical, AppTheme.spacing4)
                }
            }
            .padding(AppTheme.spacing16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportView()
    }
    .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
    .environment(AppConfigViewModel())
    .environment(SubscriptionViewModel())
}

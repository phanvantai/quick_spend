import SwiftUI
import SwiftData

/// Date range options for reports
enum ReportPeriod: CaseIterable {
    case thisMonth, lastMonth, last3Months

    func label(language: String) -> String {
        switch self {
        case .thisMonth: return L10n.tr("report.this_month", language)
        case .lastMonth: return L10n.tr("report.last_month", language)
        case .last3Months: return L10n.tr("report.three_months", language)
        }
    }

    /// Whether this period requires Premium subscription
    var requiresPremium: Bool {
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
                        currency: appConfig.config.currency,
                        periodTransactions: periodTransactions
                    )
                }

                if !topExpenses.isEmpty {
                    topExpensesSection
                }
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing12)
        }
        .navigationTitle(L10n.tr("report.title", appConfig.language))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onChange(of: selectedPeriod) { _, newPeriod in
            if newPeriod.requiresPremium && !subscription.isPremium {
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
                if period.requiresPremium && !subscription.isPremium {
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
                Text(L10n.tr("common.balance", appConfig.language))
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
                    label: L10n.tr("common.income", appConfig.language),
                    amount: stats.totalIncome,
                    count: stats.incomeCount
                )
                Spacer()
                statItem(
                    icon: "arrow.down.circle.fill",
                    color: AppTheme.expenseColor,
                    label: L10n.tr("common.expense", appConfig.language),
                    amount: stats.totalExpenses,
                    count: stats.expenseCount
                )
            }

            Divider()

            // Daily average + Savings rate
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("home.daily_average", appConfig.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appConfig.formatCurrency(stats.totalExpenses / Double(daysInPeriod)))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.tr("home.savings_rate", appConfig.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", stats.savingsRate))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(stats.savingsRate >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
                }
            }
        }
        .cardBackground()
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
                Text(L10n.tr("transactions.count", appConfig.language, count))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Top Expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(L10n.tr("home.top_expenses", appConfig.language))
                .font(.headline)

            VStack(spacing: AppTheme.spacing8) {
                ForEach(Array(topExpenses.enumerated()), id: \.element.id) { index, transaction in
                    let category = categories.first { $0.id == transaction.categoryId }
                    HStack(spacing: AppTheme.spacing12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        CategoryIconBadge(
                            iconName: category?.iconName ?? "questionmark.circle",
                            color: category?.color ?? .secondary,
                            size: 36,
                            iconFont: .body,
                            shape: .circle
                        )

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
            .cardBackground()
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

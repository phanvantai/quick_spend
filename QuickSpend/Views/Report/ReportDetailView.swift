import SwiftUI
import SwiftData
import Charts

/// Date range options shown in the period picker. `lastMonth` and
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

/// Drill-down report screen reached from Home's "View full report" link.
///
/// Consolidates v2.4's ReportView + ReportSection — same period picker
/// (current month / last month / last 3 months, with premium gating), same
/// summary stats, but the donut and category list live inline so the
/// Home-level FocalChartCard isn't pulled into a second context.
struct ReportDetailView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: CategoryStats?
    @State private var showPaywall = false

    // MARK: - Computed stats

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

    private var activeBreakdown: [CategoryStats] {
        selectedType == .expense ? stats.expenseCategoryBreakdown : stats.incomeCategoryBreakdown
    }

    private var activeTotal: Double {
        selectedType == .expense ? stats.totalExpenses : stats.totalIncome
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
                breakdownSection
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
        .sheet(item: $selectedCategory) { category in
            CategoryTransactionsSheet(
                category: category,
                transactions: periodTransactions.filter { $0.categoryId == category.categoryId },
                language: appConfig.language,
                currency: appConfig.config.currency
            )
        }
    }

    // MARK: - Period picker

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

    // MARK: - Summary stats

    private var summaryStats: some View {
        VStack(spacing: AppTheme.spacing12) {
            HStack {
                Text(L10n.tr("common.balance", appConfig.language))
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appConfig.formatCurrency(stats.netBalance))
                    .font(Typography.titleMedium.monospacedDigit())
                    .foregroundStyle(stats.netBalance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
            }

            Divider()

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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("home.daily_average", appConfig.language))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(appConfig.formatCurrency(stats.totalExpenses / Double(daysInPeriod)))
                        .font(Typography.bodyEmphasized.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.tr("home.savings_rate", appConfig.language))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", stats.savingsRate))
                        .font(Typography.bodyEmphasized.monospacedDigit())
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
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Text(appConfig.formatCurrency(amount))
                    .font(Typography.bodyEmphasized.monospacedDigit())
                    .foregroundStyle(color)
                Text(L10n.tr("transactions.count", appConfig.language, count))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Breakdown (donut + category list)

    @ViewBuilder
    private var breakdownSection: some View {
        if activeBreakdown.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                TransactionTypePicker(selection: $selectedType, language: appConfig.language)

                donutChart

                categoryList
            }
            .cardBackground()
        }
    }

    private let minPercentForLabel: Double = 8

    private var donutChart: some View {
        Chart(activeBreakdown) { stat in
            SectorMark(
                angle: .value("Amount", stat.totalAmount),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: stat.colorHex))
            .annotation(position: .overlay) {
                if stat.percentage >= minPercentForLabel {
                    Text("\(String(format: "%.0f", stat.percentage))%")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
        .chartBackground { _ in
            GeometryReader { geometry in
                VStack(spacing: AppTheme.spacing4) {
                    Text(selectedType == .expense ? L10n.tr("home.spent", appConfig.language) : L10n.tr("home.earned", appConfig.language))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(AmountAbbreviator.abbreviate(activeTotal, currency: appConfig.config.currency, language: appConfig.language))
                        .font(Typography.titleMedium)
                        .monospacedDigit()
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            ForEach(activeBreakdown) { stat in
                Button {
                    selectedCategory = stat
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        CategoryIconBadge(
                            iconName: stat.iconName,
                            color: Color(hex: stat.colorHex),
                            size: 36,
                            iconFont: .body,
                            shape: .circle
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.categoryName)
                                .font(Typography.body)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(L10n.tr("transactions.count", appConfig.language, stat.count))
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(appConfig.formatCurrency(stat.totalAmount))
                                .font(Typography.bodyEmphasized.monospacedDigit())
                                .foregroundStyle(stat.type == .expense ? AppTheme.expenseColor : AppTheme.incomeColor)
                            Text(String(format: "%.1f%%", stat.percentage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, AppTheme.spacing8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if stat.id != activeBreakdown.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Top expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(L10n.tr("home.top_expenses", appConfig.language))
                .font(Typography.headline)

            VStack(spacing: AppTheme.spacing8) {
                ForEach(Array(topExpenses.enumerated()), id: \.element.id) { index, transaction in
                    let category = categories.first { $0.id == transaction.categoryId }
                    HStack(spacing: AppTheme.spacing12) {
                        Text("\(index + 1)")
                            .font(Typography.caption.bold())
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
                                .font(Typography.body)
                                .lineLimit(1)
                            Text(category?.name ?? "—")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(appConfig.formatCurrency(transaction.amount))
                            .font(Typography.bodyEmphasized.monospacedDigit())
                            .foregroundStyle(AppTheme.expenseColor)
                    }
                    .padding(.vertical, AppTheme.spacing4)
                }
            }
            .cardBackground()
        }
    }
}

// MARK: - Category Transactions Sheet
// Lifted from the deleted ReportSection.swift — used here for the tap-to-drill
// behavior on each category row.

private struct CategoryTransactionsSheet: View {
    let category: CategoryStats
    let transactions: [Transaction]
    let language: String
    let currency: String

    @Environment(\.dismiss) private var dismiss

    private var sortedTransactions: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing16) {
                    VStack(spacing: AppTheme.spacing8) {
                        CategoryIconBadge(
                            iconName: category.iconName,
                            color: Color(hex: category.colorHex),
                            size: 56,
                            iconFont: .title2,
                            shape: .circle
                        )
                        Text(category.categoryName)
                            .font(Typography.titleMedium)
                        Text(AppConfig(language: language, currency: currency).formatCurrency(category.totalAmount))
                            .font(Typography.titleMedium.monospacedDigit())
                            .foregroundStyle(category.type == .expense ? AppTheme.expenseColor : AppTheme.incomeColor)
                        Text(L10n.tr("transactions.count", language, category.count))
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacing16)
                    .cardBackground()

                    VStack(spacing: AppTheme.spacing8) {
                        ForEach(sortedTransactions) { transaction in
                            transactionRow(transaction)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
            }
            .navigationTitle(category.categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note.isEmpty ? category.categoryName : transaction.note)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(transaction.date, style: .date)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(transaction.isIncome ? "+" : "-")\(AppConfig(language: language, currency: currency).formatCurrency(transaction.amount))")
                .font(Typography.bodyEmphasized.monospacedDigit())
                .foregroundStyle(transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)
        }
        .padding(AppTheme.spacing12)
        .cardBackground()
    }
}

#Preview {
    NavigationStack {
        ReportDetailView()
    }
    .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
    .environment(AppConfigViewModel())
    .environment(SubscriptionViewModel())
}

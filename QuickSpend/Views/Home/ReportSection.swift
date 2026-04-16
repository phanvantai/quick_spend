import SwiftUI
import Charts

/// Donut chart report with category breakdown and segmented expense/income picker
struct ReportSection: View {
    let expenseBreakdown: [CategoryStats]
    let incomeBreakdown: [CategoryStats]
    let totalExpenses: Double
    let totalIncome: Double
    let expenseChangePercent: Double
    let incomeChangePercent: Double
    let language: String
    let currency: String
    var periodTransactions: [Transaction]? = nil

    @State private var selectedTab: TransactionType = .expense
    @State private var selectedCategory: CategoryStats?

    private var activeBreakdown: [CategoryStats] {
        selectedTab == .expense ? expenseBreakdown : incomeBreakdown
    }

    private var activeTotal: Double {
        selectedTab == .expense ? totalExpenses : totalIncome
    }

    private var activeChangePercent: Double {
        selectedTab == .expense ? expenseChangePercent : incomeChangePercent
    }

    private var centerLabel: String {
        selectedTab == .expense ? HomeStrings.spent(language) : HomeStrings.earned(language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(HomeStrings.reportTitle(language))
                .font(.headline)

            VStack(spacing: AppTheme.spacing16) {
                // Segmented picker
                TransactionTypePicker(selection: $selectedTab, language: language)

                if activeBreakdown.isEmpty {
                    emptyState
                } else {
                    // Donut chart
                    donutChart

                    // Tappable category list (ReportView) or simple legend (HomeView)
                    if periodTransactions != nil {
                        categoryList
                    } else {
                        categoryLegend
                    }
                }
            }
            .cardBackground()
        }
        .sheet(item: $selectedCategory) { category in
            CategoryTransactionsSheet(
                category: category,
                transactions: (periodTransactions ?? []).filter { $0.categoryId == category.categoryId },
                language: language,
                currency: currency
            )
        }
    }

    // MARK: - Donut Chart

    /// Minimum percentage for a slice to display its own label
    private let minPercentForLabel: Double = 8

    private var donutChart: some View {
        Chart(activeBreakdown) { stat in
            SectorMark(
                angle: .value("Amount", stat.totalAmount),
                innerRadius: .ratio(0.55),
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
                    Text(centerLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(AmountAbbreviator.abbreviate(activeTotal, currency: currency, language: language))
                        .font(.title2.bold().monospacedDigit())
                    changeBadge
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private var changeBadge: some View {
        ChangeBadge(percent: activeChangePercent, style: .standalone)
    }

    // MARK: - Category Legend (compact, for HomeView)

    private var categoryLegend: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacing8), count: 2)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.spacing8) {
            ForEach(activeBreakdown) { stat in
                HStack(spacing: AppTheme.spacing4) {
                    Circle()
                        .fill(Color(hex: stat.colorHex))
                        .frame(width: 8, height: 8)
                    Text(stat.categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Category List (tappable, for ReportView)

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
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(L10n.tr("transactions.count", language, stat.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CurrencyFormatter.format(stat.totalAmount, currency: currency, language: language))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
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

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyDataView(icon: "chart.pie", message: L10n.tr("common.no_data", language))
    }
}

// MARK: - Category Transactions Sheet

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
                    // Category header
                    VStack(spacing: AppTheme.spacing8) {
                        CategoryIconBadge(
                            iconName: category.iconName,
                            color: Color(hex: category.colorHex),
                            size: 56,
                            iconFont: .title2,
                            shape: .circle
                        )
                        Text(category.categoryName)
                            .font(.title3.bold())
                        Text(CurrencyFormatter.format(category.totalAmount, currency: currency, language: language))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(category.type == .expense ? AppTheme.expenseColor : AppTheme.incomeColor)
                        Text(L10n.tr("transactions.count", language, category.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacing16)
                    .cardBackground()

                    // Transactions list
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
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(transaction.isIncome ? "+" : "-")\(CurrencyFormatter.format(transaction.amount, currency: currency, language: language))")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)
        }
        .padding(AppTheme.spacing12)
        .cardBackground()
    }
}

#Preview {
    ReportSection(
        expenseBreakdown: [
            CategoryStats(categoryId: "1", categoryName: "Chi khác", totalAmount: 7_800_000, count: 10, percentage: 96, colorHex: "00C896", iconName: "ellipsis.circle", type: .expense),
            CategoryStats(categoryId: "2", categoryName: "Sinh hoạt", totalAmount: 200_000, count: 3, percentage: 2.5, colorHex: "FFC043", iconName: "house", type: .expense),
            CategoryStats(categoryId: "3", categoryName: "Chi phí tài chính", totalAmount: 100_000, count: 1, percentage: 1.5, colorHex: "9E9EB5", iconName: "banknote", type: .expense),
        ],
        incomeBreakdown: [],
        totalExpenses: 8_100_000,
        totalIncome: 12_000_000,
        expenseChangePercent: 12,
        incomeChangePercent: -14,
        language: "vi",
        currency: "VND",
        periodTransactions: []
    )
    .padding()
}

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

    @State private var selectedTab: TransactionType = .expense

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
                Picker("Type", selection: $selectedTab) {
                    Text(HomeStrings.expense(language)).tag(TransactionType.expense)
                    Text(HomeStrings.income(language)).tag(TransactionType.income)
                }
                .pickerStyle(.segmented)

                if activeBreakdown.isEmpty {
                    emptyState
                } else {
                    // Donut chart
                    donutChart

                    // Category legend
                    categoryLegend
                }

            }
            .padding(AppTheme.spacing16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    // MARK: - Donut Chart

    private var donutChart: some View {
        Chart(activeBreakdown) { stat in
            SectorMark(
                angle: .value("Amount", stat.totalAmount),
                innerRadius: .ratio(0.65),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: stat.colorHex))
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
        .overlay(alignment: .bottomTrailing) {
            // Largest segment percentage
            if let largest = activeBreakdown.first {
                Text("\(String(format: "%.0f", largest.percentage))%")
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: largest.colorHex))
                    .padding(.trailing, AppTheme.spacing8)
                    .padding(.bottom, AppTheme.spacing8)
            }
        }
    }

    private var changeBadge: some View {
        let isUp = activeChangePercent >= 0
        let arrow = isUp ? "↑" : "↓"
        let displayPercent = abs(activeChangePercent)

        return Text("\(arrow) \(String(format: "%.0f", displayPercent))%")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isUp ? AppTheme.dashboardExpenseBar : AppTheme.dashboardIncomeBar)
            .padding(.horizontal, AppTheme.spacing8)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(isUp ? AppTheme.dashboardExpenseBar.opacity(0.15) : AppTheme.dashboardIncomeBar.opacity(0.15))
            }
    }

    // MARK: - Category Legend

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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(language == "vi" ? "Chưa có dữ liệu" : "No data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
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
        currency: "VND"
    )
    .padding()
}

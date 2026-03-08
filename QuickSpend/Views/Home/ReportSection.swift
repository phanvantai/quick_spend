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
                TransactionTypePicker(selection: $selectedTab, language: language)

                if activeBreakdown.isEmpty {
                    emptyState
                } else {
                    // Donut chart
                    donutChart

                    // Category legend
                    categoryLegend
                }

            }
            .cardBackground()
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
        EmptyDataView(icon: "chart.pie", message: L10n.tr("common.no_data", language))
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

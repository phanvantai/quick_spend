import SwiftUI
import Charts

/// v3.0 Home focal chart — one chart, two views toggled by a segmented picker:
///
/// - **Donut**: expense breakdown by category. Center label shows the total.
///   For the full income + expense drill-down, users tap "View full report".
/// - **Bar**: income vs expense comparison for the selected month.
///
/// Selection is bound to AppConfigViewModel.focalChartPreference so the
/// pick survives app relaunch. The transition between chart types animates
/// with `.springSmooth`.
struct FocalChartCard: View {
    let selection: FocalChartPreference
    let onSelectionChange: (FocalChartPreference) -> Void
    let expenseBreakdown: [CategoryStats]
    let totalIncome: Double
    let totalExpense: Double
    let incomeChangePercent: Double
    let expenseChangePercent: Double
    let language: String
    let currency: String

    @Namespace private var chartTransition

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            picker

            chartContent
                .transition(.scale.combined(with: .opacity))
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .shadow(.card)
        .animation(.springSmooth, value: selection)
    }

    // MARK: - Segmented picker

    private var picker: some View {
        Picker("", selection: Binding(
            get: { selection },
            set: { onSelectionChange($0) }
        )) {
            Text(L10n.tr("home.chart.donut", language)).tag(FocalChartPreference.donut)
            Text(L10n.tr("home.chart.bar", language)).tag(FocalChartPreference.bar)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart switching

    @ViewBuilder
    private var chartContent: some View {
        switch selection {
        case .donut:
            donutView
                .matchedGeometryEffect(id: "chart", in: chartTransition)
        case .bar:
            barView
                .matchedGeometryEffect(id: "chart", in: chartTransition)
        }
    }

    // MARK: - Donut

    /// Slices smaller than this don't render their own % label (would overflow).
    private let minPercentForLabel: Double = 8

    @ViewBuilder
    private var donutView: some View {
        if expenseBreakdown.isEmpty {
            emptyState(icon: "chart.pie")
        } else {
            VStack(spacing: AppTheme.spacing12) {
                donutChart
                categoryLegend
            }
        }
    }

    private var donutChart: some View {
        Chart(expenseBreakdown) { stat in
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
        .frame(height: 200)
        .chartBackground { _ in
            GeometryReader { geometry in
                VStack(spacing: AppTheme.spacing4) {
                    Text(L10n.tr("home.spent", language))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(AmountAbbreviator.abbreviate(totalExpense, currency: currency, language: language))
                        .font(Typography.titleMedium)
                        .monospacedDigit()
                    if totalExpense > 0 {
                        ChangeBadge(percent: expenseChangePercent, style: .standalone)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private var categoryLegend: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacing8), count: 2)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.spacing8) {
            ForEach(expenseBreakdown) { stat in
                HStack(spacing: AppTheme.spacing4) {
                    Circle()
                        .fill(Color(hex: stat.colorHex))
                        .frame(width: 8, height: 8)
                    Text(stat.categoryName)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Bar

    @ViewBuilder
    private var barView: some View {
        if totalIncome == 0 && totalExpense == 0 {
            emptyState(icon: "chart.bar")
        } else {
            HStack(alignment: .bottom, spacing: AppTheme.spacing24) {
                Spacer()
                barColumn(
                    amount: totalIncome,
                    changePercent: incomeChangePercent,
                    label: L10n.tr("common.income", language),
                    color: AppTheme.dashboardIncomeBar
                )
                barColumn(
                    amount: totalExpense,
                    changePercent: expenseChangePercent,
                    label: L10n.tr("common.expense", language),
                    color: AppTheme.dashboardExpenseBar
                )
                Spacer()
            }
            .frame(height: 220)
        }
    }

    private func barColumn(amount: Double, changePercent: Double, label: String, color: Color) -> some View {
        let maxAmount = max(totalIncome, totalExpense, 1)
        let maxBarHeight: CGFloat = 160
        let barHeight = (amount / maxAmount) * maxBarHeight

        return VStack(spacing: AppTheme.spacing8) {
            if amount > 0 {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(color)
                        .frame(width: 100, height: max(barHeight, 60))

                    VStack(spacing: AppTheme.spacing4) {
                        ChangeBadge(percent: changePercent, style: .overlay)
                        Text(AmountAbbreviator.abbreviate(amount, currency: currency, language: language))
                            .font(Typography.bodyEmphasized.monospacedDigit())
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, AppTheme.spacing12)
                }
            } else {
                VStack(spacing: AppTheme.spacing4) {
                    ChangeBadge(percent: changePercent, style: .standalone)
                    Text(AmountAbbreviator.abbreviate(0, currency: currency, language: language))
                        .font(Typography.bodyEmphasized.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 100)
                .padding(.top, AppTheme.spacing12)
            }

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String) -> some View {
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.secondary)
            Text(L10n.tr("common.no_data", language))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }
}

#Preview {
    @Previewable @State var selection: FocalChartPreference = .donut

    FocalChartCard(
        selection: selection,
        onSelectionChange: { selection = $0 },
        expenseBreakdown: [
            CategoryStats(categoryId: "1", categoryName: "Ăn uống", totalAmount: 4_500_000, count: 12, percentage: 55, colorHex: "00C896", iconName: "fork.knife", type: .expense),
            CategoryStats(categoryId: "2", categoryName: "Sinh hoạt", totalAmount: 2_500_000, count: 5, percentage: 31, colorHex: "FFC043", iconName: "house", type: .expense),
            CategoryStats(categoryId: "3", categoryName: "Khác", totalAmount: 1_100_000, count: 3, percentage: 14, colorHex: "9E9EB5", iconName: "ellipsis.circle", type: .expense),
        ],
        totalIncome: 12_000_000,
        totalExpense: 8_100_000,
        incomeChangePercent: -14,
        expenseChangePercent: 12,
        language: "vi",
        currency: "VND"
    )
    .padding()
}

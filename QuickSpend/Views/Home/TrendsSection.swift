import SwiftUI
import Charts

/// 12-month income/expense trend line chart split into two 6-month segments
struct TrendsSection: View {
    let trendData: [MonthlyTrend]
    let language: String
    let currency: String

    @State private var selectedHalf: Int = 1  // 0 = first half, 1 = second half (recent)
    @State private var selectedMonth: String?

    private var firstHalfLabel: String {
        guard trendData.count >= 6 else { return "" }
        return rangeLabel(from: 0, to: 5)
    }

    private var secondHalfLabel: String {
        guard trendData.count >= 12 else { return "" }
        return rangeLabel(from: 6, to: 11)
    }

    private var displayedData: [MonthlyTrend] {
        guard trendData.count >= 12 else { return trendData }
        let startIndex = selectedHalf == 0 ? 0 : 6
        let endIndex = min(startIndex + 6, trendData.count)
        return Array(trendData[startIndex..<endIndex])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            Text(L10n.tr("home.trends_title", language))
                .font(.headline)

            VStack(spacing: AppTheme.spacing16) {
                // Period segment picker
                if trendData.count >= 12 {
                    HStack(spacing: AppTheme.spacing8) {
                        periodButton(label: firstHalfLabel, tag: 0)
                        periodButton(label: secondHalfLabel, tag: 1)
                    }
                }

                if displayedData.isEmpty {
                    emptyState
                } else {
                    lineChart
                }

                // Legend
                HStack(spacing: AppTheme.spacing24) {
                    legendItem(color: AppTheme.dashboardExpenseLine, label: L10n.tr("common.expense", language))
                    legendItem(color: AppTheme.dashboardIncomeLine, label: L10n.tr("common.income", language))
                }
                .frame(maxWidth: .infinity)
            }
            .cardBackground()
        }
    }

    // MARK: - Period Button

    private func periodButton(label: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedHalf = tag
                selectedMonth = nil
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.vertical, AppTheme.spacing8)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .fill(selectedHalf == tag ? AppTheme.primaryDark.opacity(0.1) : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .stroke(selectedHalf == tag ? AppTheme.primaryDark : Color(.systemGray4), lineWidth: 1)
                }
        }
        .foregroundStyle(selectedHalf == tag ? AppTheme.primaryDark : .secondary)
    }

    // MARK: - Line Chart

    /// Flattened data points for the chart (one entry per type per month)
    private var chartPoints: [TrendChartPoint] {
        displayedData.flatMap { point in
            [
                TrendChartPoint(monthLabel: point.monthLabel, amount: point.totalExpenses, type: "expense"),
                TrendChartPoint(monthLabel: point.monthLabel, amount: point.totalIncome, type: "income")
            ]
        }
    }

    /// Selected month data for the tooltip
    private var selectedMonthData: MonthlyTrend? {
        guard let selectedMonth else { return nil }
        return displayedData.first { $0.monthLabel == selectedMonth }
    }

    private var lineChart: some View {
        Chart(chartPoints) { point in
            // Area fill with gradient opacity
            AreaMark(
                x: .value("Month", point.monthLabel),
                y: .value("Amount", point.amount),
                series: .value("Type", point.type),
                stacking: .unstacked
            )
            .foregroundStyle(
                point.type == "expense"
                    ? AppTheme.dashboardExpenseLine.opacity(0.15)
                    : AppTheme.dashboardIncomeLine.opacity(0.1)
            )
            .interpolationMethod(.linear)

            // Line
            LineMark(
                x: .value("Month", point.monthLabel),
                y: .value("Amount", point.amount),
                series: .value("Type", point.type)
            )
            .foregroundStyle(by: .value("Type", point.type))
            .interpolationMethod(.linear)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            // Data point circles
            if point.monthLabel == selectedMonth || selectedMonth == nil {
                PointMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Amount", point.amount)
                )
                .foregroundStyle(by: .value("Type", point.type))
                .symbolSize(selectedMonth == point.monthLabel ? 50 : 20)
            }
        }
        .chartForegroundStyleScale([
            "expense": AppTheme.dashboardExpenseLine,
            "income": AppTheme.dashboardIncomeLine
        ])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color(.systemGray4))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(AmountAbbreviator.abbreviate(amount, currency: currency, language: language))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(label == selectedMonth ? .primary : .secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = geometry[proxy.plotFrame!].origin
                                let location = CGPoint(
                                    x: value.location.x - origin.x,
                                    y: value.location.y - origin.y
                                )
                                if let month: String = proxy.value(atX: location.x) {
                                    // Snap to nearest data point
                                    if displayedData.contains(where: { $0.monthLabel == month }) {
                                        selectedMonth = month
                                    }
                                }
                            }
                            .onEnded { _ in
                                selectedMonth = nil
                            }
                    )
            }
        }
        .chartOverlay { proxy in
            // Tooltip annotation
            if let selectedMonth, let data = selectedMonthData {
                GeometryReader { geometry in
                    let plotFrame = geometry[proxy.plotFrame!]
                    if let xPosition: CGFloat = proxy.position(forX: selectedMonth) {
                        let maxY = max(data.totalIncome, data.totalExpenses)
                        if let yPosition: CGFloat = proxy.position(forY: maxY) {
                            tooltipView(data: data)
                                .position(
                                    x: plotFrame.origin.x + constrainTooltipX(
                                        xPosition: xPosition,
                                        plotWidth: plotFrame.width,
                                        tooltipWidth: 100
                                    ),
                                    y: plotFrame.origin.y + max(yPosition - 45, 10)
                                )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(height: 220)
    }

    // MARK: - Tooltip

    private func tooltipView(data: MonthlyTrend) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(AppTheme.dashboardIncomeLine)
                    .frame(width: 6, height: 6)
                Text(AmountAbbreviator.abbreviate(data.totalIncome, currency: currency, language: language))
                    .font(.caption.weight(.semibold))
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(AppTheme.dashboardExpenseLine)
                    .frame(width: 6, height: 6)
                Text(AmountAbbreviator.abbreviate(data.totalExpenses, currency: currency, language: language))
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }

    /// Keep tooltip within plot bounds
    private func constrainTooltipX(xPosition: CGFloat, plotWidth: CGFloat, tooltipWidth: CGFloat) -> CGFloat {
        let halfTooltip = tooltipWidth / 2
        if xPosition - halfTooltip < 0 {
            return halfTooltip
        } else if xPosition + halfTooltip > plotWidth {
            return plotWidth - halfTooltip
        }
        return xPosition
    }

    // MARK: - Helpers

    private func rangeLabel(from startIdx: Int, to endIdx: Int) -> String {
        guard startIdx < trendData.count, endIdx < trendData.count else { return "" }
        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: trendData[startIdx].month)
        let startYear = calendar.component(.year, from: trendData[startIdx].month)
        let endMonth = calendar.component(.month, from: trendData[endIdx].month)
        let endYear = calendar.component(.year, from: trendData[endIdx].month)

        if startYear == endYear {
            return String(format: "%02d - %02d/%d", startMonth, endMonth, endYear)
        }
        return String(format: "%02d/%d - %02d/%d", startMonth, startYear, endMonth, endYear)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: AppTheme.spacing4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        EmptyDataView(icon: "chart.line.uptrend.xyaxis", message: L10n.tr("common.no_data", language))
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let sampleData = (0..<12).reversed().map { offset -> MonthlyTrend in
        let month = calendar.date(byAdding: .month, value: -offset, to: now)!
        return MonthlyTrend(
            month: month,
            monthLabel: HomeStrings.monthAbbreviation(for: month, language: "vi"),
            totalExpenses: Double.random(in: 3_000_000...20_000_000),
            totalIncome: Double.random(in: 5_000_000...28_000_000)
        )
    }

    TrendsSection(
        trendData: sampleData,
        language: "vi",
        currency: "VND"
    )
    .padding()
}

// MARK: - Chart Data Point

/// A single data point for the trend chart, flattened from MonthlyTrend
private struct TrendChartPoint: Identifiable {
    let id = UUID()
    let monthLabel: String
    let amount: Double
    let type: String // "expense" or "income"
}

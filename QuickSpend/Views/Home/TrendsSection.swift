import SwiftUI
import Charts

/// 12-month income/expense trend line chart split into two 6-month segments
struct TrendsSection: View {
    let trendData: [MonthlyTrend]
    let language: String
    let currency: String

    @State private var selectedHalf: Int = 1  // 0 = first half, 1 = second half (recent)

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
            Text(HomeStrings.trendsTitle(language))
                .font(.headline)

            VStack(spacing: AppTheme.spacing16) {
                // Period segment picker
                if trendData.count >= 12 {
                    Picker("Period", selection: $selectedHalf) {
                        Text(firstHalfLabel).tag(0)
                        Text(secondHalfLabel).tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if displayedData.isEmpty {
                    emptyState
                } else {
                    lineChart
                }

                // Legend
                HStack(spacing: AppTheme.spacing24) {
                    legendItem(color: AppTheme.dashboardExpenseLine, label: HomeStrings.expense(language))
                    legendItem(color: AppTheme.dashboardIncomeLine, label: HomeStrings.income(language))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(AppTheme.spacing16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    // MARK: - Line Chart

    private var lineChart: some View {
        Chart {
            ForEach(displayedData) { point in
                // Expense area
                AreaMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Amount", point.totalExpenses)
                )
                .foregroundStyle(AppTheme.dashboardExpenseLine.opacity(0.12))
                .interpolationMethod(.catmullRom)

                // Expense line
                LineMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Amount", point.totalExpenses)
                )
                .foregroundStyle(AppTheme.dashboardExpenseLine)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .symbol(.circle)
                .symbolSize(30)

                // Income area
                AreaMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Amount", point.totalIncome)
                )
                .foregroundStyle(AppTheme.dashboardIncomeLine.opacity(0.12))
                .interpolationMethod(.catmullRom)

                // Income line
                LineMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Amount", point.totalIncome)
                )
                .foregroundStyle(AppTheme.dashboardIncomeLine)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .symbol(.circle)
                .symbolSize(30)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(Color(.systemGray4))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(AmountAbbreviator.abbreviate(amount, currency: currency, language: language))
                            .font(.caption2)
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
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
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
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(L10n.tr("common.no_data", language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
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

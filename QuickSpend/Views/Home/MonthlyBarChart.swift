import SwiftUI
import Charts

/// Bar chart showing daily income vs expense for the selected month
struct MonthlyBarChart: View {
    let selectedMonth: Date
    let expenses: [Transaction]
    let config: AppConfig

    private var dailyData: [DailyTotal] {
        let calendar = Calendar.current
        let monthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }

        // Group by day
        var incomeByDay: [Int: Double] = [:]
        var expenseByDay: [Int: Double] = [:]

        for expense in monthExpenses {
            let day = calendar.component(.day, from: expense.date)
            if expense.isIncome {
                incomeByDay[day, default: 0] += expense.amount
            } else {
                expenseByDay[day, default: 0] += expense.amount
            }
        }

        // Build data points
        let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
        var data: [DailyTotal] = []
        for day in range {
            if let income = incomeByDay[day] {
                data.append(DailyTotal(day: day, amount: income, type: .income))
            }
            if let expense = expenseByDay[day] {
                data.append(DailyTotal(day: day, amount: expense, type: .expense))
            }
        }
        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("home.daily_overview", config.language))
                .font(.headline)

            if dailyData.isEmpty {
                Text(L10n.tr("home.no_transactions_month", config.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(dailyData) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(item.type == .income ? AppTheme.incomeColor : AppTheme.expenseColor)
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5)) { value in
                        AxisValueLabel {
                            if let day = value.as(Int.self) {
                                Text("\(day)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(abbreviateAmount(amount))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }

            // Legend
            HStack(spacing: AppTheme.spacing16) {
                legendItem(color: AppTheme.incomeColor, label: L10n.tr("common.income", config.language))
                legendItem(color: AppTheme.expenseColor, label: L10n.tr("common.expense", config.language))
            }
            .font(.caption)
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func abbreviateAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", amount / 1_000)
        }
        return String(format: "%.0f", amount)
    }
}

private struct DailyTotal: Identifiable {
    let day: Int
    let amount: Double
    let type: TransactionType
    var id: String { "\(day)-\(type.rawValue)" }
}

#Preview {
    MonthlyBarChart(
        selectedMonth: .now,
        expenses: [],
        config: AppConfig()
    )
    .padding()
}

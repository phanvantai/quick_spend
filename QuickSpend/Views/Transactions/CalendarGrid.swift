import SwiftUI

/// Monthly calendar grid showing daily income/expense totals
struct CalendarGrid: View {
    let selectedMonth: Date
    let expenses: [Transaction]
    let currency: String
    let language: String
    @Binding var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Locale-aware weekday symbols based on the language setting
    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language)
        return calendar.veryShortWeekdaySymbols
    }

    /// Daily totals for the month
    private var dailyTotals: [Int: (income: Double, expense: Double)] {
        let calendar = Calendar.current
        var totals: [Int: (income: Double, expense: Double)] = [:]
        for exp in expenses {
            guard calendar.isDate(exp.date, equalTo: selectedMonth, toGranularity: .month) else { continue }
            let day = calendar.component(.day, from: exp.date)
            var current = totals[day] ?? (0, 0)
            if exp.isIncome {
                current.income += exp.amount
            } else {
                current.expense += exp.amount
            }
            totals[day] = current
        }
        return totals
    }

    /// First weekday offset (0 = Sunday)
    private var firstWeekdayOffset: Int {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month], from: selectedMonth)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps) else { return 0 }
        return (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
    }

    var body: some View {
        VStack(spacing: AppTheme.spacing8) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset (use negative IDs to avoid collision with day numbers)
                ForEach((-firstWeekdayOffset)..<0, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }

                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    let data = dailyTotals[day]
                    let isToday = isToday(day: day)
                    let isSelected = isSelected(day: day)

                    CalendarDayCell(
                        day: day,
                        income: data?.income ?? 0,
                        expense: data?.expense ?? 0,
                        isToday: isToday,
                        isSelected: isSelected,
                        hasData: data != nil,
                        currency: currency,
                        language: language
                    ) {
                        let calendar = Calendar.current
                        var comps = calendar.dateComponents([.year, .month], from: selectedMonth)
                        comps.day = day
                        if let date = calendar.date(from: comps) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.spacing8)
    }

    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let today = Date.now
        return calendar.component(.day, from: today) == day
            && calendar.isDate(today, equalTo: selectedMonth, toGranularity: .month)
    }

    private func isSelected(day: Int) -> Bool {
        guard let sel = selectedDate else { return false }
        let calendar = Calendar.current
        return calendar.component(.day, from: sel) == day
            && calendar.isDate(sel, equalTo: selectedMonth, toGranularity: .month)
    }
}

// MARK: - Day Cell

private struct CalendarDayCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let day: Int
    let income: Double
    let expense: Double
    let isToday: Bool
    let isSelected: Bool
    let hasData: Bool
    let currency: String
    let language: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.caption.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? AppTheme.adaptiveAccent(colorScheme) : hasData ? Color.primary : Color.secondary.opacity(0.5))

                if hasData {
                    if income > 0 {
                        Text("+\(AmountAbbreviator.abbreviate(income, currency: currency, language: language))")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppTheme.incomeColor)
                            .lineLimit(1)
                    }
                    if expense > 0 {
                        Text("-\(AmountAbbreviator.abbreviate(expense, currency: currency, language: language))")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppTheme.expenseColor)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(isSelected ? AppTheme.adaptiveAccent(colorScheme).opacity(0.1) :
                            hasData ? Color(.tertiarySystemGroupedBackground) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .stroke(isToday ? AppTheme.adaptiveAccent(colorScheme) : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }


}

#Preview {
    @Previewable @State var selectedDate: Date? = nil
    CalendarGrid(
        selectedMonth: .now,
        expenses: [],
        currency: "USD",
        language: "en",
        selectedDate: $selectedDate
    )
}

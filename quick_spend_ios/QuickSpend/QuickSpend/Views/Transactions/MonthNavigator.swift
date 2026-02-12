import SwiftUI

/// Month navigation controls (previous/next)
struct MonthNavigator: View {
    @Binding var selectedMonth: Date

    private var monthLabel: String {
        selectedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }

            Spacer()

            Text(monthLabel)
                .font(.title3.bold())

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .padding(.horizontal, AppTheme.spacing4)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        // Don't go past current month
        if newMonth <= Date() || value < 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonth = newMonth
            }
        }
    }
}

#Preview {
    @Previewable @State var month = Date()
    MonthNavigator(selectedMonth: $month)
        .padding()
}

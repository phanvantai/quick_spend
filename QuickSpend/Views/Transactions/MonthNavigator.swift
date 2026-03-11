import SwiftUI

/// Reusable month navigation: chevrons + tappable label that opens a date picker sheet
struct MonthNavigator: View {
    @Binding var selectedMonth: Date
    var language: String = "en"

    @Environment(\.colorScheme) private var colorScheme
    @State private var showDatePicker = false

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing8) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            // Tappable month label — opens date picker
            Button {
                showDatePicker.toggle()
            } label: {
                HStack(spacing: AppTheme.spacing4) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(AppTheme.primaryDark)
                    Text(HomeStrings.monthLabel(for: selectedMonth, language: language))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .sheet(isPresented: $showDatePicker) {
            monthPickerSheet
        }
    }

    // MARK: - Month Picker Sheet

    private var monthPickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Select Month",
                selection: Binding(
                    get: { selectedMonth },
                    set: { selectedMonth = $0 }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppTheme.adaptiveAccent(colorScheme))
            .padding()
            .navigationTitle(L10n.tr("home.select_month", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done", language)) {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Month Navigation

    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        // Don't go past current month (compare at month granularity)
        if value < 0 || calendar.compare(newMonth, to: .now, toGranularity: .month) != .orderedDescending {
            selectedMonth = newMonth
        }
    }
}

#Preview {
    @Previewable @State var month = Date()
    MonthNavigator(selectedMonth: $month)
        .padding()
}

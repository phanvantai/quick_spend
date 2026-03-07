import SwiftUI

/// App bar with month navigation chevrons and native DatePicker on tap
struct HomeAppBar: View {
    @Binding var selectedMonth: Date
    let language: String
    let currency: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var showDatePicker = false

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    /// Month selector portion (leading side of nav bar)
    var monthSelector: some View {
        HStack(spacing: AppTheme.spacing8) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            // Tappable month label — opens native date picker
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

    /// Currency badge (trailing side of nav bar)
    var currencyBadge: some View {
        Text(currency)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppTheme.spacing12)
            .padding(.vertical, AppTheme.spacing4)
            .background {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            }
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            monthSelector
            Spacer()
            currencyBadge
        }
    }

    // MARK: - Month Picker Sheet

    private var monthPickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Select Month",
                selection: Binding(
                    get: { selectedMonth },
                    set: { newDate in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMonth = newDate
                        }
                    }
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
        guard let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        if newMonth <= Date() || value < 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonth = newMonth
            }
        }
    }
}

#Preview {
    @Previewable @State var month = Date()
    HomeAppBar(selectedMonth: $month, language: "vi", currency: "VND")
        .padding()
}

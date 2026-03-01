import SwiftUI

/// Custom app bar with month navigation capsule and currency badge
struct HomeAppBar: View {
    @Binding var selectedMonth: Date
    let language: String
    let currency: String

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: .now, toGranularity: .month)
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            // Month selector capsule
            HStack(spacing: AppTheme.spacing8) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: AppTheme.spacing4) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryDark)
                    Text(HomeStrings.monthLabel(for: selectedMonth, language: language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing8)
            .background {
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }

            Spacer()

            // Currency badge
            Text(currency)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.vertical, AppTheme.spacing8)
                .background {
                    Capsule()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        }
    }

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

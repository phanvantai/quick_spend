import SwiftUI

/// App bar with month navigation (reuses MonthNavigator) and currency badge
struct HomeAppBar: View {
    @Binding var selectedMonth: Date
    let language: String
    let currency: String

    /// Currency badge (trailing side of nav bar)
    private var currencyBadge: some View {
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
            MonthNavigator(selectedMonth: $selectedMonth, language: language)
            Spacer()
            currencyBadge
        }
    }
}

#Preview {
    @Previewable @State var month = Date()
    HomeAppBar(selectedMonth: $month, language: "vi", currency: "VND")
        .padding()
}

import SwiftUI

/// Reusable tappable row for selecting a setting (language, currency, etc.)
/// Shows an icon/symbol, label, current value, and a "Change" action text.
struct SettingSelectionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let changeText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacing12) {
                Text(icon)
                    .font(.title2.bold())
                    .foregroundStyle(iconColor)
                    .frame(width: 36, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(changeText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primaryMint)
            }
            .padding(AppTheme.spacing16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
    }
}

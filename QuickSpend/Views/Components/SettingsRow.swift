import SwiftUI

/// Standardized row used across SettingsView sections.
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: icon,
                color: iconColor,
                size: 36,
                iconFont: .body
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

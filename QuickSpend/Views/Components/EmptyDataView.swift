import SwiftUI

/// Reusable empty state view for sections with no data
struct EmptyDataView: View {
    let icon: String
    let message: String
    var minHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: AppTheme.spacing8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}

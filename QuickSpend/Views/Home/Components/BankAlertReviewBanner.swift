import SwiftUI

/// Home card shown while bank alerts wait in the review list, or while
/// bank-alert transactions are still uncategorized.
struct BankAlertReviewBanner: View {
    enum Kind {
        case review, uncategorized

        var icon: String { self == .review ? "tray.full.fill" : "questionmark.folder.fill" }
        var titleKey: String { self == .review ? "bank_alert.banner.title" : "bank_alert.banner.uncategorized_title" }
        var subtitleKey: String { self == .review ? "bank_alert.banner.subtitle" : "bank_alert.banner.uncategorized_subtitle" }
    }

    let count: Int
    let language: String
    var kind: Kind = .review
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.spacing12) {
                CategoryIconBadge(iconName: kind.icon, color: AppTheme.accentOrange, size: 36, iconFont: .body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr(kind.titleKey, language, count))
                        .font(Typography.bodyEmphasized)
                        .foregroundStyle(.primary)
                    Text(L10n.tr(kind.subtitleKey, language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacing12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.accentOrange.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

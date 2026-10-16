import SwiftUI

/// Short confirmation after a confident voice parse was saved without review —
/// the in-app counterpart of the Siri success snippet.
struct AutoSavedToast: View {
    let items: [ParsedTransaction]
    let categories: [Category]
    let wallets: [Wallet]
    let config: AppConfig

    private var single: ParsedTransaction? {
        items.count == 1 ? items.first : nil
    }

    /// Net of income and expenses in a multi-item save; transfers don't change it.
    private var total: Double {
        items.filter { !$0.isTransfer }.reduce(0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(VoiceSummary.saved(items, wallets: wallets, config: config))
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if single == nil {
                    Text("\(L10n.tr("intent.snippet.total", config.language)): \(config.formatCurrency(abs(total)))")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.success)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
                .shadow(.card)
        )
        .padding(.horizontal, AppTheme.spacing16)
    }

    @ViewBuilder
    private var icon: some View {
        if let single, single.isTransfer {
            CategoryIconBadge(iconName: Transfer.iconName, color: AppTheme.accentTeal, size: 32, iconFont: .footnote)
        } else if let single, let category = categories.first(where: { $0.id == single.categoryId }) {
            CategoryIconBadge(iconName: category.iconName, color: category.color, size: 32, iconFont: .footnote)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.success)
        }
    }
}

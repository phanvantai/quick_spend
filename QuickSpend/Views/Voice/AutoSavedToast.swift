import SwiftUI

/// Short confirmation after a confident voice parse was saved without review —
/// the in-app counterpart of the Siri success snippet.
struct AutoSavedToast: View {
    let transactions: [Transaction]
    let categories: [Category]
    let config: AppConfig

    private var single: Transaction? {
        transactions.count == 1 ? transactions.first : nil
    }

    private var title: String {
        if let single {
            return L10n.tr(
                "intent.auto_saved_one",
                config.language,
                config.formatCurrency(single.amount),
                single.note
            )
        }
        return L10n.tr("intent.auto_saved_many", config.language, transactions.count)
    }

    /// Net of the batch, shown for multi-item saves.
    private var total: Double {
        transactions.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            if let single, let category = categories.first(where: { $0.id == single.categoryId }) {
                CategoryIconBadge(
                    iconName: category.iconName,
                    color: category.color,
                    size: 32,
                    iconFont: .footnote
                )
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.success)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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
}

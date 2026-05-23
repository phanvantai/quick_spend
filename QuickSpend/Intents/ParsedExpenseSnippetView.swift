import SwiftUI

/// Compact preview of one or more parsed transactions, rendered inside the
/// Siri / Shortcuts confirmation card.
///
/// Siri presents snippets on a translucent dark "glass" card in both light and
/// dark iOS modes (iOS 17+). We force the snippet to render with the dark
/// colour scheme so SwiftUI's semantic `.primary` / `.secondary` resolve to
/// light text — guaranteeing contrast regardless of the host trait collection.
/// We deliberately do NOT draw our own background: the Siri card supplies one,
/// and stacking a Material on top was producing dark-on-dark in dark mode.
struct ParsedExpenseSnippetView: View {
    let items: [ParsedTransaction]
    let categories: [Category]
    let config: AppConfig

    var body: some View {
        VStack(spacing: AppTheme.spacing8) {
            ForEach(items) { item in
                row(for: item)
            }
            if items.count > 1 {
                Divider()
                    .overlay(Color.white.opacity(0.25))
                HStack {
                    Text(L10n.tr("intent.snippet.total", config.language))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(config.formatCurrency(totalAmount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, AppTheme.spacing12)
        .padding(.horizontal, AppTheme.spacing16)
        .colorScheme(.dark)
    }

    private var totalAmount: Double {
        items.reduce(0) { partial, item in
            partial + (item.type == .income ? item.amount : -item.amount)
        }
        .magnitude
    }

    private func category(for item: ParsedTransaction) -> Category? {
        categories.first { $0.id == item.categoryId }
    }

    private func row(for item: ParsedTransaction) -> some View {
        let matched = category(for: item)
        return HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: matched?.iconName ?? "questionmark.circle",
                color: matched?.color ?? .gray,
                size: 36,
                iconFont: .callout
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppTheme.spacing4) {
                    Text(item.note.isEmpty ? (matched?.name ?? "Expense") : item.note)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if item.confidence < AppConstants.confidenceWarningThreshold {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                Text(matched?.name ?? item.categoryId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(signedAmount(for: item))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.type == .income ? AppTheme.success : .primary)
        }
    }

    private func signedAmount(for item: ParsedTransaction) -> String {
        let formatted = config.formatCurrency(item.amount)
        return item.type == .income ? "+\(formatted)" : formatted
    }
}

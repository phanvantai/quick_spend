import SwiftUI

/// Transaction card showing category icon, name, note, and amount in a rounded card
struct TransactionCard: View {
    let transaction: Transaction
    let category: Category?
    let config: AppConfig

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            // Circular category icon
            Circle()
                .fill((category?.color ?? .secondary).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: category?.iconName ?? "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(category?.color ?? .secondary)
                }

            // Category name and description
            VStack(alignment: .leading, spacing: 3) {
                Text(category?.name ?? L10n.tr("transactions.other", config.language))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.isIncome ? "+" : "-")\(config.formatCurrency(transaction.amount))")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)

                if let confidence = transaction.confidence, confidence < AppConstants.confidenceWarningThreshold {
                    Text(L10n.tr("transactions.low_confidence", config.language))
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule().fill(AppTheme.warning.opacity(0.15))
                        }
                }
            }
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

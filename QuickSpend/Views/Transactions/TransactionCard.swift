import SwiftUI

/// Transaction card showing category icon, name, note, and amount in a rounded card.
/// Transfer legs show the other wallet instead of a category, in a neutral color.
struct TransactionCard: View {
    let transaction: Transaction
    let category: Category?
    let wallet: Wallet?
    let transferCounterpart: Wallet?
    let config: AppConfig

    init(
        transaction: Transaction,
        category: Category?,
        wallet: Wallet? = nil,
        transferCounterpart: Wallet? = nil,
        config: AppConfig
    ) {
        self.transaction = transaction
        self.category = category
        self.wallet = wallet
        self.transferCounterpart = transferCounterpart
        self.config = config
    }

    private var iconName: String {
        transaction.isTransfer ? Transfer.iconName : (category?.iconName ?? "questionmark.circle")
    }

    private var iconColor: Color {
        transaction.isTransfer ? AppTheme.accentTeal : (category?.color ?? .secondary)
    }

    private var title: String {
        guard transaction.isTransfer else {
            return category?.name ?? L10n.tr("transactions.other", config.language)
        }
        guard let counterpart = transferCounterpart else {
            return L10n.tr("transfer.title", config.language)
        }
        let key = transaction.transferLeg == .incoming ? "transfer.from_wallet" : "transfer.to_wallet"
        return L10n.tr(key, config.language, counterpart.displayName(language: config.language))
    }

    private var amountColor: Color {
        if transaction.isTransfer { return .primary }
        return transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            // Circular category icon
            CategoryIconBadge(
                iconName: iconName,
                color: iconColor,
                size: 48,
                iconFont: .title3,
                shape: .circle
            )

            // Category name and description
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let wallet {
                    walletBadge(wallet)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.isIncome ? "+" : "-")\(config.formatCurrency(transaction.amount))")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(amountColor)

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
        .cardBackground(shadow: true)
    }

    private func walletBadge(_ wallet: Wallet) -> some View {
        HStack(spacing: AppTheme.spacing4) {
            Image(systemName: wallet.iconName)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 12, height: 12)

            Text(wallet.displayName(language: config.language))
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(wallet.color)
        .padding(.horizontal, AppTheme.spacing8)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(wallet.color.opacity(0.12))
        }
    }
}

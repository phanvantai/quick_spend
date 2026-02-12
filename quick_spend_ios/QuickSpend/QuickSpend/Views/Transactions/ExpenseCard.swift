import SwiftUI

/// Expense row card showing category icon, description, amount
struct ExpenseCard: View {
    let expense: Expense
    let category: QuickCategory?
    let config: AppConfig

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            // Category icon
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill((category?.color ?? .secondary).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: category?.iconName ?? "questionmark.circle")
                        .foregroundStyle(category?.color ?? .secondary)
                }

            // Description and category
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.descriptionText)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: AppTheme.spacing4) {
                    Text(category?.name ?? "Other")
                        .font(.caption)
                        .foregroundStyle(category?.color ?? .secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(expense.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(expense.isIncome ? "+" : "-")\(config.formatCurrency(expense.amount))")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(expense.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)

                if expense.confidence < AppConstants.confidenceWarningThreshold {
                    Text("Low confidence")
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
        .padding(.vertical, AppTheme.spacing4)
    }
}

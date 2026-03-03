import SwiftUI

/// Summary card showing income, expense, and net balance for a month
struct MonthlySummaryCard: View {
    let income: Double
    let expense: Double
    let config: AppConfig

    private var netBalance: Double { income - expense }

    var body: some View {
        VStack(spacing: AppTheme.spacing16) {
            HStack(spacing: AppTheme.spacing24) {
                summaryItem(
                    title: L10n.tr("common.income", config.language),
                    amount: income,
                    icon: "arrow.up.circle.fill",
                    color: .white.opacity(0.9)
                )

                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.3))

                summaryItem(
                    title: L10n.tr("common.expense", config.language),
                    amount: expense,
                    icon: "arrow.down.circle.fill",
                    color: .white.opacity(0.9)
                )
            }

            Divider()
                .background(Color.white.opacity(0.3))

            HStack {
                Text(L10n.tr("common.balance", config.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(config.formatCurrency(netBalance))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding(AppTheme.spacing20)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(AppTheme.summaryGradient)
        }
    }

    private func summaryItem(title: String, amount: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(color)

            Text(config.formatCurrency(amount))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MonthlySummaryCard(
        income: 5000000,
        expense: 3200000,
        config: AppConfig(language: "vi", currency: "VND")
    )
    .padding()
}

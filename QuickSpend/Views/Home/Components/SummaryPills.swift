import SwiftUI

/// v3.0 Home summary — two horizontal pills showing the month's income and
/// expense totals with a percentage change badge each.
///
/// Replaces the bar chart in OverviewSection. Smaller footprint, faster to
/// glance, and visually quieter so the focal chart below gets the attention.
struct SummaryPills: View {
    let totalIncome: Double
    let totalExpense: Double
    let incomeChangePercent: Double
    let expenseChangePercent: Double
    let language: String
    let currency: String

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            pill(
                title: L10n.tr("common.income", language),
                amount: totalIncome,
                changePercent: incomeChangePercent,
                color: AppTheme.incomeColor,
                icon: "arrow.down.left"
            )
            pill(
                title: L10n.tr("common.expense", language),
                amount: totalExpense,
                changePercent: expenseChangePercent,
                color: AppTheme.expenseColor,
                icon: "arrow.up.right"
            )
        }
    }

    private func pill(title: String, amount: Double, changePercent: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing4) {
            HStack(spacing: AppTheme.spacing4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if amount > 0 {
                    ChangeBadge(percent: changePercent, style: .standalone)
                }
            }

            Text(AmountAbbreviator.abbreviate(amount, currency: currency, language: language))
                .font(Typography.monoHeadline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .animatedNumber(amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(radius: AppTheme.radiusMedium, padding: AppTheme.spacing12)
    }
}

#Preview {
    SummaryPills(
        totalIncome: 12_000_000,
        totalExpense: 8_100_000,
        incomeChangePercent: -14,
        expenseChangePercent: 12,
        language: "vi",
        currency: "VND"
    )
    .padding()
}

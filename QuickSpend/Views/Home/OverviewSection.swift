import SwiftUI

/// Income/expense visual comparison bars with percentage change badges
struct OverviewSection: View {
    let totalExpenses: Double
    let totalIncome: Double
    let netBalance: Double
    let expenseChangePercent: Double
    let incomeChangePercent: Double
    let language: String
    let currency: String

    private let maxBarHeight: CGFloat = 160
    private let barWidth: CGFloat = 120

    private var maxAmount: Double {
        max(totalExpenses, totalIncome, 1)
    }

    private var hasData: Bool {
        totalExpenses > 0 || totalIncome > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            // Header
            Text(HomeStrings.overviewTitle(language))
                .font(.headline)

            if hasData {
                // Balance subtitle
                Text("\(HomeStrings.balance(language)): \(AmountAbbreviator.abbreviate(netBalance, currency: currency, language: language))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Comparison bars card
                HStack(alignment: .bottom, spacing: AppTheme.spacing24) {
                    Spacer()
                    barColumn(
                        amount: totalExpenses,
                        changePercent: expenseChangePercent,
                        label: HomeStrings.expense(language),
                        color: AppTheme.dashboardExpenseBar
                    )
                    barColumn(
                        amount: totalIncome,
                        changePercent: incomeChangePercent,
                        label: HomeStrings.income(language),
                        color: AppTheme.dashboardIncomeBar
                    )
                    Spacer()
                }
                .padding(AppTheme.spacing16)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.spacing12) {
            Image(systemName: "chart.bar.fill")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text(L10n.tr("common.no_data", language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func barColumn(amount: Double, changePercent: Double, label: String, color: Color) -> some View {
        let barHeight = maxAmount > 0 ? (amount / maxAmount) * maxBarHeight : 0

        return VStack(spacing: AppTheme.spacing8) {
            if amount > 0 {
                // Bar with overlaid text
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(color)
                        .frame(width: barWidth, height: max(barHeight, 60))

                    VStack(spacing: AppTheme.spacing4) {
                        changeBadge(percent: changePercent)
                        Text(AmountAbbreviator.abbreviate(amount, currency: currency, language: language))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, AppTheme.spacing12)
                }
            } else {
                // Zero state: just show the value without a bar
                VStack(spacing: AppTheme.spacing4) {
                    changeBadge(percent: changePercent)
                    Text(AmountAbbreviator.abbreviate(0, currency: currency, language: language))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: barWidth)
                .padding(.top, AppTheme.spacing12)
            }

            // Label below bar
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func changeBadge(percent: Double) -> some View {
        let isUp = percent >= 0
        let arrow = isUp ? "↑" : "↓"
        let displayPercent = abs(percent)

        return Text("\(arrow) \(String(format: "%.0f", displayPercent))%")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, AppTheme.spacing8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.25))
            }
    }
}

#Preview {
    OverviewSection(
        totalExpenses: 8_100_000,
        totalIncome: 12_000_000,
        netBalance: 3_900_000,
        expenseChangePercent: 12,
        incomeChangePercent: -14,
        language: "vi",
        currency: "VND"
    )
    .padding()
}

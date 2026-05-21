import SwiftUI

/// Hero card showing the user's current account balance — sits above the month
/// picker on Home so the "all-time" balance is visually separated from the
/// month-scoped summary below.
///
/// States:
/// - `currentBalance == nil`: setup CTA (user is on the upgrade path and hasn't
///   created an anchor yet — fresh installs always have one from the onboarding
///   completion path).
/// - `currentBalance != nil`: formatted balance hero. Negative values use the
///   expense color plus a tappable caption hint.
struct BalanceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let currentBalance: Double?
    let language: String
    let currency: String
    let onTap: () -> Void

    private var config: AppConfig {
        AppConfig(language: language, currency: currency)
    }

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("BalanceCard")
    }

    @ViewBuilder
    private var content: some View {
        if let balance = currentBalance {
            balanceContent(balance)
        } else {
            setupContent
        }
    }

    // MARK: - Display state

    private func balanceContent(_ balance: Double) -> some View {
        let isNegative = balance < 0
        let amountColor: Color = isNegative ? AppTheme.expenseColor : .primary

        return VStack(alignment: .leading, spacing: AppTheme.spacing4) {
            Text(L10n.tr("balance.title", language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            heroAmount(balance, color: amountColor)

            if isNegative {
                Text(L10n.tr("balance.negative_hint", language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// Renders the balance with a smaller inline currency symbol. The number uses
    /// the rounded design at 36/22pt per the design review.
    private func heroAmount(_ balance: Double, color: Color) -> some View {
        let formatted = config.formatNumber(balance)
        let symbol = config.currencySymbol
        let placeBefore = symbolGoesBefore(language: language, currency: currency)

        return HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing4) {
            if placeBefore {
                Text(symbol)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
                Text(formatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text(formatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(symbol)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }

    /// USD/JPY use leading symbols; VND/EUR use trailing. Mirror the locale
    /// behavior we already get from Apple's currency formatter elsewhere.
    static func symbolGoesBefore(language: String, currency: String) -> Bool {
        switch currency {
        case "USD", "JPY": return true
        default:           return false
        }
    }

    private func symbolGoesBefore(language: String, currency: String) -> Bool {
        Self.symbolGoesBefore(language: language, currency: currency)
    }

    // MARK: - Setup CTA state

    private var setupContent: some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: "banknote.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("balance.setup_cta", language))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(L10n.tr("balance.setup_subtitle", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

#Preview("Positive") {
    BalanceCard(currentBalance: 1_234_567, language: "vi", currency: "VND", onTap: {})
        .padding()
}

#Preview("Negative") {
    BalanceCard(currentBalance: -50_000, language: "vi", currency: "VND", onTap: {})
        .padding()
}

#Preview("Setup") {
    BalanceCard(currentBalance: nil, language: "en", currency: "USD", onTap: {})
        .padding()
}

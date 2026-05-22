import SwiftUI

/// v3.0 Home hero — the user's all-time account balance, dominant on screen.
///
/// Replaces the smaller BalanceCard from v2.4. Uses Typography.display for the
/// number and the animatedNumber modifier from Motion so balance edits roll up
/// instead of snapping. Tap opens the BalanceEditSheet via `onTap`.
///
/// States:
/// - `currentBalance == nil`: setup CTA (only happens on the upgrade path
///   from v2.4 — fresh installs create an anchor during onboarding).
/// - `currentBalance != nil`: gradient hero card. Negative values render in
///   the expense color with a caption hint.
struct BalanceHero: View {
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
        .accessibilityIdentifier("BalanceHero")
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

        return VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("balance.title", language))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            heroAmount(balance, isNegative: isNegative)
                .animatedNumber(balance)
                .animation(.springSmooth, value: balance)

            if isNegative {
                Text(L10n.tr("balance.negative_hint", language))
                    .font(Typography.caption)
                    .foregroundStyle(AppTheme.expenseColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(radius: AppTheme.radiusLarge, padding: AppTheme.spacing20, shadow: true)
    }

    /// Gradient text fill for positive balances; flat expense color for negatives.
    private func amountStyle(isNegative: Bool) -> AnyShapeStyle {
        if isNegative {
            return AnyShapeStyle(AppTheme.expenseColor)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryMint, Color(hex: "5EEAD4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// Renders the balance with a smaller inline currency symbol. The number
    /// uses Typography.display (rounded, 40pt) so it dominates the screen.
    private func heroAmount(_ balance: Double, isNegative: Bool) -> some View {
        let formatted = config.formatNumber(balance)
        let symbol = config.currencySymbol
        let placeBefore = symbolGoesBefore(language: language, currency: currency)
        let style = amountStyle(isNegative: isNegative)

        return HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing4) {
            if placeBefore {
                Text(symbol)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(style)
                heroNumber(formatted, style: style)
            } else {
                heroNumber(formatted, style: style)
                Text(symbol)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(style)
            }
        }
    }

    private func heroNumber(_ text: String, style: AnyShapeStyle) -> some View {
        Text(text)
            .font(Typography.display)
            .foregroundStyle(style)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .monospacedDigit()
    }

    /// USD/JPY use leading symbols; VND/EUR use trailing.
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
                .font(.title)
                .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("balance.setup_cta", language))
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(.primary)
                Text(L10n.tr("balance.setup_subtitle", language))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(radius: AppTheme.radiusLarge, padding: AppTheme.spacing20, shadow: true)
    }
}

#Preview("Positive") {
    BalanceHero(currentBalance: 1_234_567, language: "vi", currency: "VND", onTap: {})
        .padding()
}

#Preview("Negative") {
    BalanceHero(currentBalance: -50_000, language: "vi", currency: "VND", onTap: {})
        .padding()
}

#Preview("Setup") {
    BalanceHero(currentBalance: nil, language: "en", currency: "USD", onTap: {})
        .padding()
}

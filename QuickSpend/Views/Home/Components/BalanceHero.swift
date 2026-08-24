import SwiftUI

/// v3.0 Home hero — the user's all-time account balance, dominant on screen.
///
/// Layout: leading accent stripe + subtle dot pattern background + uppercase
/// label + big monospaced amount + inline month-net delta. Tap opens wallet
/// management via `onTap`; balance changes live in the wallet edit form.
///
/// States:
/// - `currentBalance == nil`: setup CTA (fresh-install skipped the balance
///   step, or v2.4 upgrade with no anchor synced yet).
/// - `currentBalance != nil`: amount renders in primary color, negatives in
///   the expense color with a hint caption.
struct BalanceHero: View {
    @Environment(\.colorScheme) private var colorScheme
    let currentBalance: Double?
    /// Net change for the currently-viewed month (income − expense). nil hides
    /// the delta row entirely (e.g. on first launch with no transactions yet).
    let monthlyNet: Double?
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
        let amountColor: Color = isNegative ? AppTheme.expenseColor : .primary

        return HStack(alignment: .top, spacing: AppTheme.spacing12) {
            accentStripe(color: AppTheme.adaptiveAccent(colorScheme))

            VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                Text(L10n.tr("balance.title", language))
                    .font(Typography.captionEmphasized)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                heroAmount(balance, color: amountColor)
                    .animatedNumber(balance)
                    .animation(.springSmooth, value: balance)

                if isNegative {
                    Text(L10n.tr("balance.negative_hint", language))
                        .font(Typography.caption)
                        .foregroundStyle(AppTheme.expenseColor)
                } else if let monthlyNet, monthlyNet != 0 {
                    deltaChip(monthlyNet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppTheme.spacing20)
            .padding(.trailing, AppTheme.spacing20)
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .fill(Color(.secondarySystemGroupedBackground))

                DotPattern(color: AppTheme.adaptiveAccent(colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.06))
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black, .black],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .shadow(.card)
    }

    /// Solid accent rectangle, full card height, hugging the leading edge.
    private func accentStripe(color: Color) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4)
    }

    /// Inline "this month" delta — arrow + signed currency value.
    private func deltaChip(_ net: Double) -> some View {
        let isPositive = net > 0
        let color: Color = isPositive ? AppTheme.incomeColor : AppTheme.expenseColor
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let formatted = config.formatCurrency(abs(net))
        let sign = isPositive ? "+" : "−"

        return HStack(spacing: AppTheme.spacing4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text("\(sign)\(formatted)")
                .font(Typography.captionEmphasized.monospacedDigit())
            Text(L10n.tr("balance.this_month", language))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppTheme.spacing8)
        .padding(.vertical, AppTheme.spacing4)
        .background(
            Capsule().fill(color.opacity(colorScheme == .dark ? 0.18 : 0.12))
        )
    }

    /// Renders the balance with a smaller inline currency symbol.
    private func heroAmount(_ balance: Double, color: Color) -> some View {
        let formatted = config.formatNumber(balance)
        let symbol = config.currencySymbol
        let placeBefore = symbolGoesBefore(language: language, currency: currency)

        return HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacing4) {
            if placeBefore {
                Text(symbol)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
                heroNumber(formatted, color: color)
            } else {
                heroNumber(formatted, color: color)
                Text(symbol)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }

    private func heroNumber(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Typography.display)
            .foregroundStyle(color)
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
            accentStripe(color: AppTheme.adaptiveAccent(colorScheme))

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
            .padding(.vertical, AppTheme.spacing20)
            .padding(.trailing, AppTheme.spacing20)
        }
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .shadow(.card)
    }
}

/// Repeating dot grid drawn with Canvas — used as a subtle texture on
/// BalanceHero. Color comes from the caller so light/dark tones differ.
private struct DotPattern: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 14
            let radius: CGFloat = 1.4
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Positive") {
    BalanceHero(currentBalance: 1_234_567, monthlyNet: 500_000, language: "vi", currency: "VND", onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Negative") {
    BalanceHero(currentBalance: -50_000, monthlyNet: -120_000, language: "vi", currency: "VND", onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Setup") {
    BalanceHero(currentBalance: nil, monthlyNet: nil, language: "en", currency: "USD", onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}

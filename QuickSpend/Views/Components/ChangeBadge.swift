import SwiftUI

/// Reusable percentage change badge with arrow indicator
struct ChangeBadge: View {
    let percent: Double
    var style: BadgeStyle = .overlay

    enum BadgeStyle {
        /// White text on translucent white background (for use on colored bars)
        case overlay
        /// Colored text on translucent colored background (for use on light backgrounds)
        case standalone
    }

    private var isUp: Bool { percent >= 0 }
    private var arrow: String { isUp ? "↑" : "↓" }
    private var displayPercent: Double { abs(percent) }

    var body: some View {
        Text("\(arrow) \(String(format: "%.0f", displayPercent))%")
            .font(style == .overlay ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, AppTheme.spacing8)
            .padding(.vertical, style == .overlay ? 3 : 2)
            .background {
                Capsule()
                    .fill(backgroundColor)
            }
    }

    private var foregroundColor: Color {
        switch style {
        case .overlay:
            return .white.opacity(0.9)
        case .standalone:
            return isUp ? AppTheme.dashboardExpenseBar : AppTheme.dashboardIncomeBar
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .overlay:
            return Color.white.opacity(0.25)
        case .standalone:
            return isUp ? AppTheme.dashboardExpenseBar.opacity(0.15) : AppTheme.dashboardIncomeBar.opacity(0.15)
        }
    }
}

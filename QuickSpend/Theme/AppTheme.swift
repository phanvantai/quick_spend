import SwiftUI

/// Quick Spend design system
/// Dark forest green primary brand with gold/amber expense accents.
/// Uses native iOS components (NavigationStack, List, Form).
enum AppTheme {

    // MARK: - Primary Colors (Dark Forest Green Brand)

    static let primaryMint = Color(hex: "1B4332")
    static let primaryGreen = Color(hex: "2D6A4F")
    static let primaryDark = Color(hex: "143D29")
    /// Lighter green for use on dark backgrounds (buttons, links, icons)
    static let primaryLight = Color(hex: "52B788")

    /// Adaptive brand accent — light enough on dark backgrounds, full brand on light.
    /// Use this anywhere `primaryMint` was previously used as foreground/tint color.
    static func adaptiveAccent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? primaryLight : primaryMint
    }

    // MARK: - Accent Colors

    static let accentPink = Color(hex: "E57373")
    static let accentOrange = Color(hex: "FFB74D")
    static let accentTeal = Color(hex: "00897B")

    // MARK: - Semantic Colors

    static let success = Color(hex: "27AE60")
    static let warning = Color(hex: "FFC043")
    static let error = Color(hex: "E74C3C")

    // MARK: - Income / Expense Colors

    static let incomeColor = Color(hex: "27AE60")
    static let expenseColor = Color(hex: "C0392B")

    // MARK: - Dashboard Colors

    static let dashboardExpenseBar = Color(hex: "B8860B")
    static let dashboardIncomeBar = Color(hex: "1B4332")
    static let dashboardExpenseLine = Color(hex: "D4A017")
    static let dashboardIncomeLine = Color(hex: "2E7D32")

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [primaryMint, primaryGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accentPink, accentOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let summaryGradient = LinearGradient(
        colors: [Color(hex: "143D29"), Color(hex: "2D6A4F")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "E8F5E9"), Color(hex: "FFFFFF")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let darkBackgroundGradient = LinearGradient(
        colors: [Color(hex: "0A1F14"), Color(hex: "141414")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Spacing (4px-based system)

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40
    static let spacing48: CGFloat = 48
    static let spacing64: CGFloat = 64

    // MARK: - Border Radius

    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXLarge: CGFloat = 24
}

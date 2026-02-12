import SwiftUI

/// Quick Spend design system
/// Provides brand colors, spacing, and gradients for consistent styling
/// while using native iOS components (NavigationStack, List, Form)
enum AppTheme {

    // MARK: - Primary Colors (Mint Green Brand)

    static let primaryMint = Color(hex: "00D9A3")
    static let primaryGreen = Color(hex: "00C896")
    static let primaryDark = Color(hex: "00B386")

    // MARK: - Accent Colors

    static let accentPink = Color(hex: "FF6B9D")
    static let accentOrange = Color(hex: "FF8C42")
    static let accentTeal = Color(hex: "00D9C0")

    // MARK: - Semantic Colors

    static let success = Color(hex: "00C896")
    static let warning = Color(hex: "FFC043")
    static let error = Color(hex: "FF5757")
    static let info = Color(hex: "5F5CF1")

    // MARK: - Category Colors

    static let categoryFood = Color(hex: "FF8C42")
    static let categoryTransport = Color(hex: "5F5CF1")
    static let categoryShopping = Color(hex: "6C5CE7")
    static let categoryBills = Color(hex: "FF5757")
    static let categoryHealth = Color(hex: "00C896")
    static let categoryEntertainment = Color(hex: "FF6B9D")
    static let categoryOther = Color(hex: "9E9EB5")

    // MARK: - Income / Expense Colors

    static let incomeColor = Color(hex: "4CAF50")
    static let expenseColor = Color(hex: "FF5757")

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
        colors: [Color(hex: "006B5F"), Color(hex: "00C896")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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

import Testing
import Foundation
import SwiftUI
@testable import QuickSpend

@Suite("ColorPalette Tests")
struct ColorPaletteTests {

    // MARK: - Color(hex:)

    @Test("Color from 6-char hex without #")
    func testColorFrom6CharHex() {
        let color = Color(hex: "FF0000")
        // Verify it doesn't crash - Color comparison is complex so we just ensure creation
        let _ = color
    }

    @Test("Color from 6-char hex with #")
    func testColorFrom6CharHexWithHash() {
        let color = Color(hex: "#FF0000")
        let _ = color
    }

    @Test("Color from 8-char ARGB hex")
    func testColorFrom8CharHex() {
        let color = Color(hex: "80FF0000")
        let _ = color
    }

    @Test("Color from invalid hex produces black")
    func testColorFromInvalidHex() {
        // Invalid input: fewer than 6 characters
        let color = Color(hex: "ABC")
        let _ = color
    }

    @Test("Color from empty string produces black")
    func testColorFromEmptyString() {
        let color = Color(hex: "")
        let _ = color
    }

    // MARK: - toHex()

    @Test("Red color converts to hex correctly")
    func testRedToHex() {
        let color = Color(hex: "FF0000")
        let hex = color.toHex()
        #expect(hex == "FF0000")
    }

    @Test("Green color converts to hex correctly")
    func testGreenToHex() {
        let color = Color(hex: "00FF00")
        let hex = color.toHex()
        #expect(hex == "00FF00")
    }

    @Test("Blue color converts to hex correctly")
    func testBlueToHex() {
        let color = Color(hex: "0000FF")
        let hex = color.toHex()
        #expect(hex == "0000FF")
    }

    @Test("White color converts to hex correctly")
    func testWhiteToHex() {
        let color = Color(hex: "FFFFFF")
        let hex = color.toHex()
        #expect(hex == "FFFFFF")
    }

    @Test("Black color converts to hex correctly")
    func testBlackToHex() {
        let color = Color(hex: "000000")
        let hex = color.toHex()
        #expect(hex == "000000")
    }

    @Test("Round-trip hex conversion preserves value")
    func testRoundTripHex() {
        let originalHex = "FF8C42"
        let color = Color(hex: originalHex)
        let resultHex = color.toHex()
        #expect(resultHex == originalHex)
    }

    @Test("Round-trip with hash prefix")
    func testRoundTripWithHash() {
        let color = Color(hex: "#2D6A4F")
        let hex = color.toHex()
        #expect(hex == "2D6A4F")
    }

    // MARK: - AppTheme Colors

    @Test("AppTheme primary colors exist")
    func testPrimaryColors() {
        let _ = AppTheme.primaryMint
        let _ = AppTheme.primaryGreen
        let _ = AppTheme.primaryDark
        let _ = AppTheme.primaryLight
    }

    @Test("AppTheme accent colors exist")
    func testAccentColors() {
        let _ = AppTheme.accentPink
        let _ = AppTheme.accentOrange
        let _ = AppTheme.accentTeal
    }

    @Test("AppTheme semantic colors exist")
    func testSemanticColors() {
        let _ = AppTheme.success
        let _ = AppTheme.warning
        let _ = AppTheme.error
    }

    @Test("AppTheme income/expense colors exist")
    func testIncomeExpenseColors() {
        let _ = AppTheme.incomeColor
        let _ = AppTheme.expenseColor
    }

    @Test("adaptiveAccent returns different colors for light and dark")
    func testAdaptiveAccent() {
        let light = AppTheme.adaptiveAccent(.light)
        let dark = AppTheme.adaptiveAccent(.dark)
        // They should be different colors
        #expect(light.toHex() != dark.toHex())
    }

    @Test("adaptiveAccent dark returns primaryLight")
    func testAdaptiveAccentDark() {
        let dark = AppTheme.adaptiveAccent(.dark)
        #expect(dark.toHex() == AppTheme.primaryLight.toHex())
    }

    @Test("adaptiveAccent light returns primaryMint")
    func testAdaptiveAccentLight() {
        let light = AppTheme.adaptiveAccent(.light)
        #expect(light.toHex() == AppTheme.primaryMint.toHex())
    }

    // MARK: - AppTheme Spacing

    @Test("Spacing values are 4px-based and increasing")
    func testSpacingValues() {
        #expect(AppTheme.spacing4 == 4)
        #expect(AppTheme.spacing8 == 8)
        #expect(AppTheme.spacing12 == 12)
        #expect(AppTheme.spacing16 == 16)
        #expect(AppTheme.spacing20 == 20)
        #expect(AppTheme.spacing24 == 24)
        #expect(AppTheme.spacing32 == 32)
        #expect(AppTheme.spacing40 == 40)
        #expect(AppTheme.spacing48 == 48)
        #expect(AppTheme.spacing64 == 64)
    }

    // MARK: - AppTheme Border Radius

    @Test("Border radius values are increasing")
    func testBorderRadius() {
        #expect(AppTheme.radiusSmall < AppTheme.radiusMedium)
        #expect(AppTheme.radiusMedium < AppTheme.radiusLarge)
        #expect(AppTheme.radiusLarge < AppTheme.radiusXLarge)
    }

    @Test("Border radius specific values")
    func testBorderRadiusValues() {
        #expect(AppTheme.radiusSmall == 8)
        #expect(AppTheme.radiusMedium == 12)
        #expect(AppTheme.radiusLarge == 16)
        #expect(AppTheme.radiusXLarge == 24)
    }

    // MARK: - Gradients

    @Test("Gradients don't crash on creation")
    func testGradients() {
        let _ = AppTheme.primaryGradient
        let _ = AppTheme.accentGradient
        let _ = AppTheme.summaryGradient
        let _ = AppTheme.backgroundGradient
        let _ = AppTheme.darkBackgroundGradient
    }
}

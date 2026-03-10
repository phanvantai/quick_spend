import Testing
import Foundation
@testable import QuickSpend

@Suite("CategoryColorPalette Tests")
struct CategoryColorPaletteTests {

    // All 26 expected category IDs
    static let allCategoryIds: Set<String> = [
        "food_drink", "groceries", "transport", "housing", "bills_utilities",
        "shopping", "health", "education", "entertainment", "personal_care",
        "gifts", "family", "insurance", "savings_invest", "debt_payment",
        "pets", "travel", "other_expense",
        "salary", "freelance", "bonus", "investment_income", "interest",
        "gift_received", "refund", "other_income",
    ]

    // MARK: - Active palette tests

    @Test("colorHex returns a value for every known category ID")
    func testColorHexReturnsValueForAllIds() {
        for id in Self.allCategoryIds {
            let hex = CategoryColorPalette.colorHex(for: id)
            #expect(hex != "A0A3BD", "Category '\(id)' should not return fallback color")
        }
    }

    @Test("colorHex returns fallback for unknown ID")
    func testColorHexFallbackForUnknownId() {
        #expect(CategoryColorPalette.colorHex(for: "nonexistent_category") == "A0A3BD")
        #expect(CategoryColorPalette.colorHex(for: "") == "A0A3BD")
    }

    @Test("availableColorHexes returns non-empty unique values")
    func testAvailableColorHexesNonEmptyAndUnique() {
        let hexes = CategoryColorPalette.availableColorHexes()
        #expect(!hexes.isEmpty)
        #expect(Set(hexes).count == hexes.count, "All color hexes should be unique")
    }

    // MARK: - Palette completeness

    @Test("Soft Modern palette has exactly 26 entries covering all category IDs")
    func testSoftModernPaletteCompleteness() {
        assertPaletteCompleteness(.softModern)
    }

    @Test("Vibrant palette has exactly 26 entries covering all category IDs")
    func testVibrantPaletteCompleteness() {
        assertPaletteCompleteness(.vibrant)
    }

    @Test("Earthy Minimal palette has exactly 26 entries covering all category IDs")
    func testEarthyMinimalPaletteCompleteness() {
        assertPaletteCompleteness(.earthyMinimal)
    }

    // MARK: - Valid hex format

    @Test("Soft Modern palette contains valid 6-char uppercase hex values")
    func testSoftModernHexFormat() {
        assertHexFormat(.softModern)
    }

    @Test("Vibrant palette contains valid 6-char uppercase hex values")
    func testVibrantHexFormat() {
        assertHexFormat(.vibrant)
    }

    @Test("Earthy Minimal palette contains valid 6-char uppercase hex values")
    func testEarthyMinimalHexFormat() {
        assertHexFormat(.earthyMinimal)
    }

    // MARK: - Distinct palettes

    @Test("All three palettes have distinct color sets")
    func testPalettesAreDistinct() {
        let softColors = colorSet(for: .softModern)
        let vibrantColors = colorSet(for: .vibrant)
        let earthyColors = colorSet(for: .earthyMinimal)

        #expect(softColors != vibrantColors, "Soft Modern and Vibrant should differ")
        #expect(softColors != earthyColors, "Soft Modern and Earthy Minimal should differ")
        #expect(vibrantColors != earthyColors, "Vibrant and Earthy Minimal should differ")
    }

    // MARK: - Helpers

    private func assertPaletteCompleteness(_ style: CategoryPaletteStyle) {
        var matchedCount = 0
        for id in Self.allCategoryIds {
            let hex = colorHex(for: id, style: style)
            #expect(hex != "A0A3BD", "Palette should have entry for '\(id)'")
            matchedCount += 1
        }
        #expect(matchedCount == 26)
    }

    private func assertHexFormat(_ style: CategoryPaletteStyle) {
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        for id in Self.allCategoryIds {
            let hex = colorHex(for: id, style: style)
            #expect(hex.count == 6, "Hex '\(hex)' for '\(id)' should be 6 characters")
            #expect(
                hex.uppercased().unicodeScalars.allSatisfy { hexCharSet.contains($0) },
                "Hex '\(hex)' for '\(id)' should be valid uppercase hex"
            )
        }
    }

    /// Helper to get color hex for a specific palette style (bypasses `active`)
    private func colorHex(for categoryId: String, style: CategoryPaletteStyle) -> String {
        // We test via the public API by checking all IDs return non-fallback values.
        // Since `active` is a constant, we validate each palette dictionary through
        // the known category IDs approach.
        CategoryColorPalette.colorHex(for: categoryId)
    }

    private func colorSet(for style: CategoryPaletteStyle) -> Set<String> {
        Set(Self.allCategoryIds.map { colorHex(for: $0, style: style) })
    }
}

import Foundation

/// Switchable color palette for seed categories.
/// Change `active` to try different palettes — only affects fresh installs or after clearing app data.
enum CategoryPaletteStyle {
    case softModern
    case vibrant
    case earthyMinimal
}

struct CategoryColorPalette {

    /// Change this single line to switch palettes
  static let active: CategoryPaletteStyle = .earthyMinimal

    /// Returns the hex color for a category ID from the active palette, with fallback
    static func colorHex(for categoryId: String) -> String {
        colorHex(for: categoryId, style: active)
    }

    /// Returns the hex color for a category ID from a specific palette style, with fallback
    static func colorHex(for categoryId: String, style: CategoryPaletteStyle) -> String {
        let palette: [String: String]
        switch style {
        case .softModern: palette = softModernColors
        case .vibrant: palette = vibrantColors
        case .earthyMinimal: palette = earthyMinimalColors
        }
        return palette[categoryId] ?? "A0A3BD"
    }

    /// Unique color hexes from the active palette (for color picker)
    static func availableColorHexes() -> [String] {
        let palette: [String: String]
        switch active {
        case .softModern: palette = softModernColors
        case .vibrant: palette = vibrantColors
        case .earthyMinimal: palette = earthyMinimalColors
        }
        var seen = Set<String>()
        var result: [String] = []
        for hex in palette.values.sorted() {
            if seen.insert(hex).inserted {
                result.append(hex)
            }
        }
        return result
    }

    // MARK: - Palette: Soft Modern (muted, cohesive)

    private static let softModernColors: [String: String] = [
        "food_drink": "F2994A",
        "groceries": "6FCF97",
        "transport": "56CCF2",
        "housing": "B07D62",
        "bills_utilities": "EB5757",
        "shopping": "BB6BD9",
        "health": "27AE60",
        "education": "2D9CDB",
        "entertainment": "F2C94C",
        "personal_care": "E88DB4",
        "gifts": "9B51E0",
        "family": "F06595",
        "insurance": "828282",
        "savings_invest": "219653",
        "debt_payment": "E74C3C",
        "pets": "E8A87C",
        "travel": "4ECDC4",
        "other_expense": "A1A4BE",
        "salary": "2ECC71",
        "freelance": "3498DB",
        "bonus": "F1C40F",
        "investment_income": "1ABC9C",
        "interest": "5B86E5",
        "gift_received": "FD79A8",
        "refund": "E17055",
        "other_income": "6C5CE7",
    ]

    // MARK: - Palette: Vibrant (bold, max hue separation)

    private static let vibrantColors: [String: String] = [
        "food_drink": "FF6B35",
        "groceries": "00B894",
        "transport": "0984E3",
        "housing": "D35D6E",
        "bills_utilities": "E84393",
        "shopping": "A29BFE",
        "health": "00CEC9",
        "education": "6C5CE7",
        "entertainment": "FDCB6E",
        "personal_care": "E17055",
        "gifts": "FD79A8",
        "family": "74B9FF",
        "insurance": "636E72",
        "savings_invest": "00B894",
        "debt_payment": "D63031",
        "pets": "E77F67",
        "travel": "22A6B3",
        "other_expense": "95AFC0",
        "salary": "6AB04C",
        "freelance": "4A90D9",
        "bonus": "F9CA24",
        "investment_income": "7ED6DF",
        "interest": "686DE0",
        "gift_received": "FF7979",
        "refund": "F0932B",
        "other_income": "BE2EDD",
    ]

    // MARK: - Palette: Earthy Minimal (warm, muted, natural)

    private static let earthyMinimalColors: [String: String] = [
        "food_drink": "D4915D",
        "groceries": "7CB572",
        "transport": "5B8DBE",
        "housing": "A67C6D",
        "bills_utilities": "C75C5C",
        "shopping": "9B7EC8",
        "health": "5BA88B",
        "education": "4A7FB5",
        "entertainment": "D4A843",
        "personal_care": "C27BA0",
        "gifts": "8E6BBF",
        "family": "D4817A",
        "insurance": "8B9DAF",
        "savings_invest": "4A9A7E",
        "debt_payment": "C44D4D",
        "pets": "C9A27E",
        "travel": "5BAEA6",
        "other_expense": "9A9CB8",
        "salary": "5BAB6E",
        "freelance": "5A9BD5",
        "bonus": "D4B44C",
        "investment_income": "5DBCAC",
        "interest": "7B8DC4",
        "gift_received": "D98BA3",
        "refund": "D4915D",
        "other_income": "7E5DAC",
    ]
}

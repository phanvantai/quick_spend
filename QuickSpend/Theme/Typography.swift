import SwiftUI

/// Semantic typography scale for QuickSpend.
///
/// Replaces ad-hoc `.font(.headline)` / `.font(.system(...))` calls scattered
/// across views. Every font respects Dynamic Type via `Font.system(_:weight:design:)`
/// or by mapping onto a built-in text style.
///
/// Naming follows role, not size — so `Typography.display` always means
/// "biggest number on the screen" regardless of platform metrics.
enum Typography {

    // MARK: - Display & Title (hero numbers, screen titles)

    /// Largest on-screen number — balance hero, focal chart center.
    static let display = Font.system(size: 40, weight: .bold, design: .rounded)

    /// Screen-level title (navigation, modal header).
    static let title = Font.system(.title, design: .default).weight(.bold)

    /// Section header inside a screen.
    static let titleMedium = Font.system(.title3).weight(.semibold)

    // MARK: - Body

    /// Section/card emphasis text — pill labels, primary CTAs.
    static let headline = Font.headline

    /// Default body text.
    static let body = Font.body

    /// Body with emphasis (use sparingly — bold body is heavy).
    static let bodyEmphasized = Font.body.weight(.semibold)

    // MARK: - Caption (metadata, change badges, hints)

    static let caption = Font.caption

    static let captionEmphasized = Font.caption.weight(.semibold)

    // MARK: - Monospaced (amounts in tables, code-like values)

    /// Monospaced body — keeps decimal columns aligned in lists.
    static let mono = Font.system(.body, design: .monospaced)

    /// Monospaced amount headline — for card-level totals.
    static let monoHeadline = Font.system(.headline, design: .monospaced).weight(.semibold)
}

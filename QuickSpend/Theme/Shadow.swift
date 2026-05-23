import SwiftUI

/// Shadow elevation tokens for QuickSpend.
///
/// Apply with `.shadow(.card)` / `.elevated` / `.floating` via the View
/// extension below. Token names describe elevation role, not raw radius —
/// `card` is for resting surfaces, `elevated` for pressed/lifted, `floating`
/// for overlays (modals, FAB).
struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = AppShadow(
        color: .black.opacity(0.06),
        radius: 4, x: 0, y: 2
    )

    static let elevated = AppShadow(
        color: .black.opacity(0.10),
        radius: 8, x: 0, y: 4
    )

    static let floating = AppShadow(
        color: .black.opacity(0.15),
        radius: 16, x: 0, y: 8
    )
}

extension View {
    /// Apply a named shadow token: `someView.shadow(.card)`.
    func shadow(_ token: AppShadow) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

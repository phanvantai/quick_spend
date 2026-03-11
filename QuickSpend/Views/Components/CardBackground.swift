import SwiftUI

/// View modifier that applies a rounded rectangle card background
struct CardBackgroundModifier: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat
    let shadow: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: shadow ? .black.opacity(0.06) : .clear,
                        radius: shadow ? 4 : 0,
                        y: shadow ? 2 : 0
                    )
            }
    }
}

extension View {
    /// Applies a card-style background with rounded corners
    func cardBackground(
        radius: CGFloat = AppTheme.radiusLarge,
        padding: CGFloat = AppTheme.spacing16,
        shadow: Bool = false
    ) -> some View {
        modifier(CardBackgroundModifier(radius: radius, padding: padding, shadow: shadow))
    }
}

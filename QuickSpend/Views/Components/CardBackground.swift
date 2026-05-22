import SwiftUI

/// Glass card background. Renders `.ultraThinMaterial` with a hairline white
/// border so cards lift over the AuroraBackground. The legacy API name is
/// kept — every call site automatically gets the v3.0 glass treatment.
struct CardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat
    let padding: CGFloat
    let shadow: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: shadow ? .black.opacity(colorScheme == .dark ? 0.35 : 0.08) : .clear,
                radius: shadow ? 16 : 0,
                y: shadow ? 8 : 0
            )
    }
}

extension View {
    /// Glass card background (frosted material + hairline border).
    func cardBackground(
        radius: CGFloat = AppTheme.radiusLarge,
        padding: CGFloat = AppTheme.spacing16,
        shadow: Bool = false
    ) -> some View {
        modifier(CardBackgroundModifier(radius: radius, padding: padding, shadow: shadow))
    }
}

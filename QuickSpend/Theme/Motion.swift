import SwiftUI

/// Motion helpers for QuickSpend.
///
/// Provides reusable view modifiers for common animated effects:
/// digit roll-up tickers on the balance hero, scroll-driven scale on parallax
/// headers. Pure UI sugar — no state, no side effects.

extension View {
    /// Smoothly animates numeric content when `value` changes, using
    /// `.springSmooth` from AnimationPreset. Mark amount/counter views with
    /// this so balance edits roll up instead of snapping.
    func animatedNumber<V: Equatable>(_ value: V) -> some View {
        contentTransition(.numericText())
            .animation(.springSmooth, value: value)
    }

    /// Subtle parallax: shrinks slightly + reduces opacity as `offset` grows
    /// (i.e. as the user scrolls down past a hero). `offset` is expected to
    /// be negative when scrolled up — typically wired to a
    /// `GeometryReader`-tracked scroll offset.
    func parallaxHero(offset: CGFloat, maxOffset: CGFloat = 120) -> some View {
        let progress = min(max(-offset / maxOffset, 0), 1)
        return scaleEffect(1 - progress * 0.08, anchor: .top)
            .opacity(1 - progress * 0.4)
    }
}

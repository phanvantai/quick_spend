import SwiftUI

/// Named animation presets for QuickSpend.
///
/// Replaces the 32+ hardcoded `.spring(response:dampingFraction:)` calls
/// across views. Three spring curves cover almost every interaction; one
/// ease covers chrome and tint changes.
///
/// Use via `withAnimation(.springFast) { ... }` or `.animation(.springSmooth, value: x)`.
extension Animation {

    /// Quick, snappy spring for taps, toggles, micro-interactions.
    /// Response 0.3s, damping 0.7 (slight bounce).
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Default spring for sheet entrances, card reveals, chart transitions.
    /// Response 0.45s, damping 0.7 (small bounce, comfortable pace).
    static let springSmooth = Animation.spring(response: 0.45, dampingFraction: 0.7)

    /// Slower spring for hero animations and long travel.
    /// Response 0.6s, damping 0.8 (minimal overshoot).
    static let springGentle = Animation.spring(response: 0.6, dampingFraction: 0.8)

    /// Linear-ish ease for chrome (color, opacity, tint).
    static let easeQuick = Animation.easeInOut(duration: 0.2)
}

import SwiftUI

/// Bag of state passed from `VoiceFABButton` down into the four visual
/// variants. Keeps each variant pure: gesture, tutorial, haptic, etc.
/// all live in the parent.
struct VoiceFABVisualContext {
    let isRecording: Bool
    let isDragCancelling: Bool
    let isPressed: Bool
    /// 0…~1 mic input level. Variants react to this while recording.
    let soundLevel: Float
    /// Adaptive primary color for the current color scheme.
    let accent: Color
    /// Recording surface color — flips to error when drag-cancel armed.
    var activeColor: Color {
        isDragCancelling ? AppTheme.error : accent
    }
}

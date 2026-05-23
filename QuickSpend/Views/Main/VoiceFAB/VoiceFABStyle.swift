import Foundation

/// Four FAB visual variants the user can switch between under
/// Settings → Preferences while we A/B test the redesign.
///
/// The raw values are persisted into `AppConfig.voiceFabStyle`; never
/// rename them. Add new cases below and bump the default if you want.
enum VoiceFABStyle: String, CaseIterable, Identifiable {
    /// Clean gradient circle + concentric ripples + 8 reactive waveform
    /// bars around the rim when recording.
    case audioBurst = "audio_burst"

    /// Squircle shape (continuous corner radius) + radial halo glow that
    /// breathes idly and pulses with soundLevel when recording.
    case squircleHalo = "squircle_halo"

    /// Circle with a conic-gradient sweep that rotates slowly when idle
    /// and accelerates while listening.
    case listeningOrb = "listening_orb"

    /// Pill with mic icon + "Hold" label inline; morphs into a circle
    /// with audio bars when recording starts.
    case holdPill = "hold_pill"

    var id: String { rawValue }

    /// Short human label for the picker. English-only because this is a
    /// dev/preview affordance; localize if it ships permanently.
    var displayName: String {
        switch self {
        case .audioBurst:    return "Audio Burst"
        case .squircleHalo:  return "Squircle Halo"
        case .listeningOrb:  return "Listening Orb"
        case .holdPill:      return "Hold Pill"
        }
    }
}

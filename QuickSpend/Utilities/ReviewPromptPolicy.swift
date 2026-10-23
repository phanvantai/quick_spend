import Foundation

/// When to ask for an App Store review: after a few successful voice saves,
/// at most once per app version. Apple still decides whether the prompt shows.
enum ReviewPromptPolicy {
    static let voiceSavesBeforePrompt = 3

    static func shouldRequest(voiceSaveCount: Int, lastPromptVersion: String?, currentVersion: String) -> Bool {
        voiceSaveCount >= voiceSavesBeforePrompt && lastPromptVersion != currentVersion
    }
}

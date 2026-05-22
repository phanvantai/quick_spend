import Foundation

/// iCloud-hosted Siri/Shortcuts URLs that pre-install the "Quick Expense" voice
/// shortcut. One per supported app language because the embedded Dictate Text
/// action has a fixed speech recognition language that must match how the user
/// speaks.
enum VoiceShortcut {
    /// Returns the iCloud install URL for the language, falling back to English
    /// if the language isn't one of the localized variants.
    static func installURL(for language: String) -> URL? {
        URL(string: urlString(for: language))
    }

    private static func urlString(for language: String) -> String {
        switch language {
        case "vi": return "https://www.icloud.com/shortcuts/1d283ae830694ada989deb4e84a95f44"
        case "ja": return "https://www.icloud.com/shortcuts/6b921bcf016846d5968086d3b6f1abb7"
        case "es": return "https://www.icloud.com/shortcuts/51522bb5f4c9408bba39f0ba76c32b63"
        default:   return "https://www.icloud.com/shortcuts/ae5de463165d4f4ebd2bc62c551fb3a0"
        }
    }
}

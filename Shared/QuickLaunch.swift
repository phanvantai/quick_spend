import Foundation
import Observation

/// Shortcuts into the app from the home/lock screen widget and Control Center.
/// Compiled into both the app and the widget extension.
enum QuickLaunchAction: String, CaseIterable {
    /// Open the app and start voice recording right away.
    case voiceExpense = "voice"

    static let scheme = "quickspend"

    var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host()?.lowercased(),
              let action = Self(rawValue: host) else { return nil }
        self = action
    }
}

/// Holds a quick-launch request until the main UI is on screen to act on it
/// (the app may still be on the splash or onboarding screen).
@MainActor
@Observable
final class QuickLaunchCenter {
    static let shared = QuickLaunchCenter()

    private(set) var pending: QuickLaunchAction?

    func request(_ action: QuickLaunchAction) {
        pending = action
    }

    /// Records the action for a `quickspend://` URL. Returns false for other URLs.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let action = QuickLaunchAction(url: url) else { return false }
        request(action)
        return true
    }

    /// Clears `action` if it is pending and reports whether it was.
    func consume(_ action: QuickLaunchAction) -> Bool {
        guard pending == action else { return false }
        pending = nil
        return true
    }
}

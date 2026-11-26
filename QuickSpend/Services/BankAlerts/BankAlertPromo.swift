import Foundation

/// The ready-made "QuickSpend · Bank alerts" shortcut, shared from iCloud. On
/// iOS 27 a shortcut carries its automation, so installing it sets up the
/// Notification trigger and the action wired to the notification's body; the
/// user only picks their banking apps.
enum BankAlertShortcut {
    /// iCloud links per app language. Empty until the shortcut is published:
    /// the "Quick install" buttons stay hidden while there is no link.
    static let installLinks: [String: String] = [:]

    static func installURL(for language: String) -> URL? {
        guard let link = installLinks[language] ?? installLinks["en"] else { return nil }
        return URL(string: link)
    }
}

/// When to introduce bank alerts: the one-time What's New modal and the Home
/// card. Both only for VND users, since alerts are read in VND.
enum BankAlertPromoPolicy {
    static func shouldShowWhatsNew(
        currency: String,
        hasSeenWhatsNew: Bool,
        earlierPromosDone: Bool
    ) -> Bool {
        earlierPromosDone && !hasSeenWhatsNew && currency.uppercased() == "VND"
    }

    /// The Home card, until the first bank-alert transaction arrives or the
    /// user closes it. Waits for the What's New modal so both don't show at once.
    static func shouldShowSetupCard(
        currency: String,
        hasSeenWhatsNew: Bool,
        cardDismissed: Bool,
        isEnabled: Bool,
        hasBankAlertActivity: Bool
    ) -> Bool {
        currency.uppercased() == "VND" && hasSeenWhatsNew && !cardDismissed && isEnabled && !hasBankAlertActivity
    }
}

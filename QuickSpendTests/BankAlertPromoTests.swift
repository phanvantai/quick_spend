import Testing
import Foundation
@testable import QuickSpend

@Suite("Bank alert promo Tests")
struct BankAlertPromoTests {

    // MARK: - What's New

    @Test("What's New shows once, after earlier promos, for VND users only")
    func whatsNew() {
        #expect(BankAlertPromoPolicy.shouldShowWhatsNew(currency: "VND", hasSeenWhatsNew: false, earlierPromosDone: true))
        #expect(BankAlertPromoPolicy.shouldShowWhatsNew(currency: "vnd", hasSeenWhatsNew: false, earlierPromosDone: true))
        #expect(!BankAlertPromoPolicy.shouldShowWhatsNew(currency: "VND", hasSeenWhatsNew: true, earlierPromosDone: true))
        #expect(!BankAlertPromoPolicy.shouldShowWhatsNew(currency: "VND", hasSeenWhatsNew: false, earlierPromosDone: false))
        #expect(!BankAlertPromoPolicy.shouldShowWhatsNew(currency: "USD", hasSeenWhatsNew: false, earlierPromosDone: true))
    }

    // MARK: - Home card

    @Test("The Home card shows for VND users after What's New, until dismissed or the first alert")
    func setupCard() {
        func show(currency: String = "VND", seen: Bool = true, dismissed: Bool = false, enabled: Bool = true, activity: Bool = false) -> Bool {
            BankAlertPromoPolicy.shouldShowSetupCard(
                currency: currency, hasSeenWhatsNew: seen, cardDismissed: dismissed,
                isEnabled: enabled, hasBankAlertActivity: activity
            )
        }
        #expect(show())
        #expect(!show(currency: "USD"))
        #expect(!show(seen: false))
        #expect(!show(dismissed: true))
        #expect(!show(enabled: false))
        #expect(!show(activity: true))
    }

    @Test("Quick install is either hidden or an iCloud shortcut link")
    func quickInstallLink() {
        for language in ["en", "vi", "ja", "es"] {
            if let url = BankAlertShortcut.installURL(for: language) {
                #expect(url.absoluteString.hasPrefix("https://www.icloud.com/shortcuts/"))
            }
        }
    }

    // MARK: - Config and preferences

    @Test("Older saved configs decode with the What's New not yet seen, and the flag round-trips")
    func configFlag() throws {
        let old = #"{"language":"vi","currency":"VND","isOnboardingComplete":true}"#.data(using: .utf8)!
        var config = try JSONDecoder().decode(AppConfig.self, from: old)
        #expect(config.hasSeenBankAlertsWhatsNew == false)

        config.hasSeenBankAlertsWhatsNew = true
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded.hasSeenBankAlertsWhatsNew)
    }

    @Test("Marking What's New seen and dismissing the card persist; clearAll resets the card")
    func preferences() {
        let service = PreferencesService(defaults: UserDefaults(suiteName: "BankAlertPromoTests-\(UUID().uuidString)")!)
        service.markBankAlertsWhatsNewSeen()
        #expect(service.getConfig().hasSeenBankAlertsWhatsNew)
        #expect(service.bankAlertsSetupCardDismissed == false)
        service.bankAlertsSetupCardDismissed = true
        #expect(service.bankAlertsSetupCardDismissed)
        service.clearAll()
        #expect(service.bankAlertsSetupCardDismissed == false)
    }

    // MARK: - Guide steps

    @Test("iOS 27 uses the in-shortcut automation steps for SMS and email")
    func guideKeys() {
        #expect(BankAlertChannel.notification.guideKey(onMajorVersion: 27) == "notification")
        #expect(BankAlertChannel.sms.guideKey(onMajorVersion: 26) == "sms")
        #expect(BankAlertChannel.sms.guideKey(onMajorVersion: 27) == "sms27")
        #expect(BankAlertChannel.email.guideKey(onMajorVersion: 18) == "email")
        #expect(BankAlertChannel.email.guideKey(onMajorVersion: 27) == "email27")
        #expect(BankAlertChannel.sms.stepCount(onMajorVersion: 26) == 5)
        #expect(BankAlertChannel.sms.stepCount(onMajorVersion: 27) == 6)
        #expect(BankAlertChannel.notification.stepCount(onMajorVersion: 27) == 6)
    }
}

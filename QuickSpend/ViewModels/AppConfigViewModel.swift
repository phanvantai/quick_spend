import Foundation
import SwiftUI

/// Observable view model for managing app configuration state
@Observable
final class AppConfigViewModel {
    private(set) var config: AppConfig
    private(set) var selectedWalletScope: WalletScope
    private(set) var defaultWalletId: String
    private let preferences: PreferencesService

    /// Supported language codes in the app
    private static let supportedLanguages: Set<String> = ["en", "vi", "ja", "es"]

    var language: String { config.language }
    var currency: String { config.currency }
    var themeMode: String { config.themeMode }
    var isOnboardingComplete: Bool { config.isOnboardingComplete }
    var hasSeenBalanceWhatsNew: Bool { config.hasSeenBalanceWhatsNew }
    var hasSeenSiriPromo: Bool { config.hasSeenSiriPromo }
    var hasSeenVoiceShortcutPromo: Bool { config.hasSeenVoiceShortcutPromo }
    var shouldShowWalletsWhatsNew: Bool { preferences.shouldShowWalletsWhatsNew }
    /// Decoded form of `config.focalChartPreference`. Unknown raw values fall
    /// back to `.donut` (mirrors the AppConfig decoder).
    var focalChartPreference: FocalChartPreference {
        FocalChartPreference(rawValue: config.focalChartPreference) ?? .donut
    }

    var colorScheme: ColorScheme? { config.colorScheme }

    convenience init() {
        self.init(preferences: .shared)
    }

    /// Testable initializer that accepts a custom PreferencesService
    init(preferences: PreferencesService) {
        self.preferences = preferences
        self.config = preferences.getConfig()
        self.selectedWalletScope = WalletScope(rawValue: preferences.selectedWalletScopeRawValue) ?? .wallet(Wallet.personalID)
        self.defaultWalletId = preferences.defaultWalletId
    }

    func setLanguage(_ language: String) {
        config.language = language
        preferences.saveConfig(config)
        // Sync to iOS per-app language setting
        Self.setSystemLanguage(language)
    }

    /// Detect the iOS per-app language setting and update AppConfig if it differs.
    /// Call this on app launch and when returning to foreground.
    func syncLanguageFromSystem() {
        guard let systemLanguage = Self.detectSystemLanguage() else { return }
        if systemLanguage != config.language {
            config.language = systemLanguage
            preferences.saveConfig(config)
        }
    }

    // MARK: - System Language Sync (Internal for testing)

    /// Resolve the iOS-level preferred language to a supported app language code.
    static func detectSystemLanguage() -> String? {
        // Locale.preferredLanguages respects the per-app language override in iOS Settings
        let preferred = Locale.preferredLanguages
        for tag in preferred {
            let code = Locale(identifier: tag).language.languageCode?.identifier ?? tag
            if supportedLanguages.contains(code) {
                return code
            }
        }
        return nil
    }

    /// Initial language for first-run onboarding: use the device/per-app language
    /// when supported, otherwise fall back to English.
    static func initialOnboardingLanguage() -> String {
        detectSystemLanguage() ?? "en"
    }

    /// Write the language to the iOS per-app language UserDefaults key.
    private static func setSystemLanguage(_ language: String) {
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
    }

    func setCurrency(_ currency: String) {
        config.currency = currency
        preferences.saveConfig(config)
    }

    func setThemeMode(_ themeMode: String) {
        config.themeMode = themeMode
        preferences.saveConfig(config)
    }

    /// Atomically marks onboarding complete AND the catch-up promo modals (Balance,
    /// Siri) as seen. The fresh-install onboarding already introduces both features
    /// (Balance whatsnew + Try Siri step), so those modals must never fire for them.
    func completeOnboarding() {
        config.isOnboardingComplete = true
        config.hasSeenBalanceWhatsNew = true
        config.hasSeenSiriPromo = true
        preferences.saveConfig(config)
    }

    /// Called from the WhatsNew modal's dismiss action for users upgrading from v2.4
    /// who never saw the in-onboarding balance step.
    func markBalanceWhatsNewSeen() {
        config.hasSeenBalanceWhatsNew = true
        preferences.saveConfig(config)
    }

    /// Called from the Siri promo modal when the user dismisses.
    func markSiriPromoSeen() {
        config.hasSeenSiriPromo = true
        preferences.saveConfig(config)
    }

    /// Called from the Voice Shortcut promo modal when the user installs the
    /// shortcut or chooses "Maybe later".
    func markVoiceShortcutPromoSeen() {
        config.hasSeenVoiceShortcutPromo = true
        preferences.saveConfig(config)
    }

    /// Persists the Home FocalChartCard's selected view (Donut vs Bar).
    func setFocalChartPreference(_ value: FocalChartPreference) {
        config.focalChartPreference = value.rawValue
        preferences.saveConfig(config)
    }

    func setDefaultWalletId(_ walletId: String) {
        defaultWalletId = walletId
        preferences.setDefaultWalletId(walletId)
    }

    func setSelectedWalletScope(_ scope: WalletScope) {
        selectedWalletScope = scope
        preferences.setSelectedWalletScope(scope)
    }

    func markWalletsWhatsNewSeen() {
        preferences.setShouldShowWalletsWhatsNew(false)
    }

    /// Bulk update (useful during onboarding)
    func updatePreferences(language: String? = nil, currency: String? = nil, isOnboardingComplete: Bool? = nil) {
        if let language {
            config.language = language
            Self.setSystemLanguage(language)
        }
        if let currency { config.currency = currency }
        if let isOnboardingComplete {
            config.isOnboardingComplete = isOnboardingComplete
            // Mirror the atomicity guarantee in completeOnboarding(): when the bulk
            // path lands on isOnboardingComplete=true, also flip the catch-up modals
            // off so fresh installs don't see Balance WhatsNew or the Siri promo
            // (the Try Siri onboarding step already covers it).
            if isOnboardingComplete {
                config.hasSeenBalanceWhatsNew = true
                config.hasSeenSiriPromo = true
            }
        }
        preferences.saveConfig(config)
    }

    /// Reset all preferences to defaults (used by "Delete All Data")
    func resetAll() {
        preferences.clearAll()
        config = AppConfig()
        selectedWalletScope = .wallet(Wallet.personalID)
        defaultWalletId = Wallet.personalID
    }

    /// Format an amount using current config
    func formatCurrency(_ amount: Double) -> String {
        config.formatCurrency(amount)
    }
}

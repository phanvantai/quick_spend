import Foundation

/// Service for managing app preferences using UserDefaults
final class PreferencesService {
    static let shared = PreferencesService()

    private let defaults: UserDefaults
    private let configKey = "app_config"
    private let voiceTutorialShownKey = "voice_tutorial_shown"
    private let voiceRecordingCountKey = "voice_recording_count"
    private let defaultWalletIdKey = "default_wallet_id"
    private let selectedWalletScopeKey = "selected_wallet_scope"
    private let walletsWhatsNewKey = "wallets_whats_new"

    private convenience init() {
        self.init(defaults: .standard)
    }

    /// Testable initializer that accepts a custom UserDefaults instance
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - App Config

    func getConfig() -> AppConfig {
        guard let data = defaults.data(forKey: configKey),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func saveConfig(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: configKey)
    }

    func setLanguage(_ language: String) { updateConfig { $0.language = language } }
    func setCurrency(_ currency: String) { updateConfig { $0.currency = currency } }
    func setThemeMode(_ themeMode: String) { updateConfig { $0.themeMode = themeMode } }

    /// Atomically marks onboarding complete AND the catch-up promo modals (Balance,
    /// Siri) as seen. Fresh installs go through the onboarding balance + Try Siri
    /// steps, so those modals — which exist to surface the features to existing v2.x
    /// users — must never fire for them.
    func completeOnboarding() {
        updateConfig {
            $0.isOnboardingComplete = true
            $0.hasSeenBalanceWhatsNew = true
            $0.hasSeenSiriPromo = true
        }
    }

    /// Marks the Balance WhatsNew modal as seen. Called from the modal's dismiss action.
    func markBalanceWhatsNewSeen() {
        updateConfig { $0.hasSeenBalanceWhatsNew = true }
    }

    /// Marks the Siri promo modal as seen.
    func markSiriPromoSeen() {
        updateConfig { $0.hasSeenSiriPromo = true }
    }

    /// Marks the Voice Shortcut promo modal as seen.
    func markVoiceShortcutPromoSeen() {
        updateConfig { $0.hasSeenVoiceShortcutPromo = true }
    }

    /// Persists the Home FocalChartCard's selected view.
    func setFocalChartPreference(_ value: FocalChartPreference) {
        updateConfig { $0.focalChartPreference = value.rawValue }
    }

    // MARK: - Wallets

    var defaultWalletId: String {
        defaults.string(forKey: defaultWalletIdKey) ?? Wallet.personalID
    }

    func setDefaultWalletId(_ walletId: String) {
        defaults.set(walletId, forKey: defaultWalletIdKey)
    }

    var selectedWalletScopeRawValue: String {
        defaults.string(forKey: selectedWalletScopeKey) ?? WalletScope.wallet(Wallet.personalID).rawValue
    }

    func setSelectedWalletScope(_ scope: WalletScope) {
        defaults.set(scope.rawValue, forKey: selectedWalletScopeKey)
    }

    var shouldShowWalletsWhatsNew: Bool {
        defaults.bool(forKey: walletsWhatsNewKey)
    }

    func setShouldShowWalletsWhatsNew(_ shouldShow: Bool) {
        defaults.set(shouldShow, forKey: walletsWhatsNewKey)
    }

    private func updateConfig(_ update: (inout AppConfig) -> Void) {
        var config = getConfig()
        update(&config)
        saveConfig(config)
    }


    // MARK: - Voice Tutorial

    var hasShownVoiceTutorial: Bool {
        defaults.bool(forKey: voiceTutorialShownKey)
    }

    func markVoiceTutorialShown() {
        defaults.set(true, forKey: voiceTutorialShownKey)
    }

    var voiceRecordingCount: Int {
        defaults.integer(forKey: voiceRecordingCountKey)
    }

    func incrementVoiceRecordingCount() {
        defaults.set(voiceRecordingCount + 1, forKey: voiceRecordingCountKey)
    }

    // MARK: - Reset

    /// Clears all preferences managed by this service.
    /// Removes keys directly from the underlying UserDefaults instance so it works
    /// correctly for both the standard suite (production) and custom test suites.
    func clearAll() {
        defaults.removeObject(forKey: configKey)
        defaults.removeObject(forKey: voiceTutorialShownKey)
        defaults.removeObject(forKey: voiceRecordingCountKey)
        defaults.removeObject(forKey: defaultWalletIdKey)
        defaults.removeObject(forKey: selectedWalletScopeKey)
        defaults.removeObject(forKey: walletsWhatsNewKey)
    }
}

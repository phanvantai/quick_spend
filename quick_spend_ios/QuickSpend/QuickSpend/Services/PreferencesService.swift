import Foundation

/// Service for managing app preferences using UserDefaults
final class PreferencesService {
    static let shared = PreferencesService()

    private let defaults = UserDefaults.standard
    private let configKey = "app_config"
    private let voiceTutorialShownKey = "voice_tutorial_shown"
    private let voiceRecordingCountKey = "voice_recording_count"

    private init() {}

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

    func setLanguage(_ language: String) {
        var config = getConfig()
        config.language = language
        saveConfig(config)
    }

    func setCurrency(_ currency: String) {
        var config = getConfig()
        config.currency = currency
        saveConfig(config)
    }

    func setThemeMode(_ themeMode: String) {
        var config = getConfig()
        config.themeMode = themeMode
        saveConfig(config)
    }

    func completeOnboarding() {
        var config = getConfig()
        config.isOnboardingComplete = true
        saveConfig(config)
    }

    func setDataCollectionConsent(_ consent: Bool) {
        var config = getConfig()
        config.dataCollectionConsent = consent
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

    func clearAll() {
        let domain = Bundle.main.bundleIdentifier ?? ""
        defaults.removePersistentDomain(forName: domain)
    }
}

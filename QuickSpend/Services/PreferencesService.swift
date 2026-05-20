import Foundation

/// Service for managing app preferences using UserDefaults
final class PreferencesService {
    static let shared = PreferencesService()

    private let defaults: UserDefaults
    private let configKey = "app_config"
    private let voiceTutorialShownKey = "voice_tutorial_shown"
    private let voiceRecordingCountKey = "voice_recording_count"

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
    func completeOnboarding() { updateConfig { $0.isOnboardingComplete = true } }

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
    }
}

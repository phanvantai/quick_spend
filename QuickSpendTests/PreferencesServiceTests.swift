import Testing
import Foundation
@testable import QuickSpend

@Suite("PreferencesService Tests")
struct PreferencesServiceTests {

    /// Create an isolated PreferencesService backed by a test-only UserDefaults suite
    private func makeService() -> PreferencesService {
        let suiteName = "test.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return PreferencesService(defaults: defaults)
    }

    // MARK: - Config

    @Test("getConfig returns default AppConfig when none saved")
    func testGetConfigDefault() {
        let service = makeService()
        let config = service.getConfig()

        #expect(config.language == "en")
        #expect(config.currency == "USD")
        #expect(config.themeMode == "system")
        #expect(config.isOnboardingComplete == false)
        #expect(config.hasSeenBalanceWhatsNew == false)
    }

    @Test("completeOnboarding atomically sets both isOnboardingComplete AND hasSeenBalanceWhatsNew — fresh install never sees the WhatsNew modal")
    func testCompleteOnboardingSetsBalanceWhatsNewAtomic() {
        let service = makeService()

        service.completeOnboarding()
        let config = service.getConfig()

        #expect(config.isOnboardingComplete == true)
        #expect(config.hasSeenBalanceWhatsNew == true)
    }

    @Test("markBalanceWhatsNewSeen flips the flag without touching isOnboardingComplete")
    func testMarkBalanceWhatsNewSeen() {
        let service = makeService()

        // Existing user state — onboarding already done from v2.4
        var existing = AppConfig()
        existing.isOnboardingComplete = true
        existing.hasSeenBalanceWhatsNew = false
        service.saveConfig(existing)

        service.markBalanceWhatsNewSeen()
        let after = service.getConfig()

        #expect(after.hasSeenBalanceWhatsNew == true)
        #expect(after.isOnboardingComplete == true)
    }

    @Test("saveConfig and getConfig round-trip")
    func testSaveAndGetConfig() {
        let service = makeService()
        var config = AppConfig()
        config.language = "vi"
        config.currency = "VND"
        config.themeMode = "dark"
        config.isOnboardingComplete = true

        service.saveConfig(config)
        let loaded = service.getConfig()

        #expect(loaded.language == "vi")
        #expect(loaded.currency == "VND")
        #expect(loaded.themeMode == "dark")
        #expect(loaded.isOnboardingComplete == true)
    }

    @Test("setLanguage updates only language")
    func testSetLanguage() {
        let service = makeService()

        service.setLanguage("ja")
        let config = service.getConfig()

        #expect(config.language == "ja")
        #expect(config.currency == "USD")  // Unchanged
    }

    @Test("setCurrency updates only currency")
    func testSetCurrency() {
        let service = makeService()

        service.setCurrency("JPY")
        let config = service.getConfig()

        #expect(config.currency == "JPY")
        #expect(config.language == "en")  // Unchanged
    }

    @Test("setThemeMode updates only theme")
    func testSetThemeMode() {
        let service = makeService()

        service.setThemeMode("dark")
        let config = service.getConfig()

        #expect(config.themeMode == "dark")
    }

    @Test("completeOnboarding sets flag to true")
    func testCompleteOnboarding() {
        let service = makeService()

        #expect(service.getConfig().isOnboardingComplete == false)

        service.completeOnboarding()

        #expect(service.getConfig().isOnboardingComplete == true)
    }


    @Test("Multiple sequential updates persist correctly")
    func testSequentialUpdates() {
        let service = makeService()

        service.setLanguage("vi")
        service.setCurrency("VND")
        service.setThemeMode("dark")
        service.completeOnboarding()

        let config = service.getConfig()
        #expect(config.language == "vi")
        #expect(config.currency == "VND")
        #expect(config.themeMode == "dark")
        #expect(config.isOnboardingComplete == true)
    }

    // MARK: - Voice Tutorial

    @Test("hasShownVoiceTutorial defaults to false")
    func testVoiceTutorialDefault() {
        let service = makeService()
        #expect(service.hasShownVoiceTutorial == false)
    }

    @Test("markVoiceTutorialShown sets flag to true")
    func testMarkVoiceTutorialShown() {
        let service = makeService()

        service.markVoiceTutorialShown()

        #expect(service.hasShownVoiceTutorial == true)
    }

    @Test("voiceRecordingCount defaults to 0")
    func testVoiceRecordingCountDefault() {
        let service = makeService()
        #expect(service.voiceRecordingCount == 0)
    }

    @Test("incrementVoiceRecordingCount increments correctly")
    func testIncrementVoiceRecordingCount() {
        let service = makeService()

        service.incrementVoiceRecordingCount()
        #expect(service.voiceRecordingCount == 1)

        service.incrementVoiceRecordingCount()
        #expect(service.voiceRecordingCount == 2)

        service.incrementVoiceRecordingCount()
        #expect(service.voiceRecordingCount == 3)
    }

    // MARK: - Config Isolation

    @Test("Two service instances don't interfere with each other")
    func testIsolation() {
        let service1 = makeService()
        let service2 = makeService()

        service1.setLanguage("vi")
        service2.setLanguage("ja")

        #expect(service1.getConfig().language == "vi")
        #expect(service2.getConfig().language == "ja")
    }

    // MARK: - clearAll

    @Test("clearAll resets config to defaults")
    func testClearAllResetsConfig() {
        let service = makeService()
        service.setLanguage("vi")
        service.setCurrency("VND")
        service.setThemeMode("dark")
        service.completeOnboarding()

        service.clearAll()

        let config = service.getConfig()
        #expect(config.language == "en")
        #expect(config.currency == "USD")
        #expect(config.themeMode == "system")
        #expect(config.isOnboardingComplete == false)
    }

    @Test("clearAll resets voice tutorial and recording count")
    func testClearAllResetsVoiceState() {
        let service = makeService()
        service.markVoiceTutorialShown()
        service.incrementVoiceRecordingCount()
        service.incrementVoiceRecordingCount()

        service.clearAll()

        #expect(service.hasShownVoiceTutorial == false)
        #expect(service.voiceRecordingCount == 0)
    }

    @Test("Overwriting config replaces all values")
    func testOverwriteConfig() {
        let service = makeService()

        var config1 = AppConfig()
        config1.language = "vi"
        config1.currency = "VND"
        service.saveConfig(config1)

        var config2 = AppConfig()
        config2.language = "ja"
        config2.currency = "JPY"
        config2.isOnboardingComplete = true
        service.saveConfig(config2)

        let loaded = service.getConfig()
        #expect(loaded.language == "ja")
        #expect(loaded.currency == "JPY")
        #expect(loaded.isOnboardingComplete == true)
    }
}

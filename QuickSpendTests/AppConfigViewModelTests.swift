import Testing
import Foundation
import SwiftUI
@testable import QuickSpend

@Suite("AppConfigViewModel Tests")
struct AppConfigViewModelTests {

    /// Create an isolated ViewModel backed by a test-only UserDefaults suite
    private func makeViewModel() -> AppConfigViewModel {
        let suiteName = "test.viewmodel.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = PreferencesService(defaults: defaults)
        return AppConfigViewModel(preferences: preferences)
    }

    // MARK: - Initial State

    @Test("ViewModel has default config on init")
    func testDefaultConfig() {
        let vm = makeViewModel()

        #expect(vm.language == "en")
        #expect(vm.currency == "USD")
        #expect(vm.themeMode == "system")
        #expect(vm.isOnboardingComplete == false)
    }

    @Test("ViewModel colorScheme defaults to nil for system")
    func testDefaultColorScheme() {
        let vm = makeViewModel()
        #expect(vm.colorScheme == nil)
    }

    // MARK: - Language

    @Test("setLanguage updates language")
    func testSetLanguage() {
        let vm = makeViewModel()

        vm.setLanguage("vi")
        #expect(vm.language == "vi")
    }

    @Test("setLanguage persists across reads")
    func testSetLanguagePersists() {
        let vm = makeViewModel()

        vm.setLanguage("ja")
        #expect(vm.config.language == "ja")
    }

    // MARK: - Currency

    @Test("setCurrency updates currency")
    func testSetCurrency() {
        let vm = makeViewModel()

        vm.setCurrency("VND")
        #expect(vm.currency == "VND")
    }

    @Test("setCurrency does not affect other fields")
    func testSetCurrencyIsolation() {
        let vm = makeViewModel()

        vm.setCurrency("JPY")
        #expect(vm.language == "en")
        #expect(vm.themeMode == "system")
    }

    // MARK: - Theme

    @Test("setThemeMode updates theme")
    func testSetThemeMode() {
        let vm = makeViewModel()

        vm.setThemeMode("dark")
        #expect(vm.themeMode == "dark")
    }

    @Test("setThemeMode to dark returns dark colorScheme")
    func testSetThemeModeDark() {
        let vm = makeViewModel()

        vm.setThemeMode("dark")
        #expect(vm.colorScheme == .dark)
    }

    @Test("setThemeMode to light returns light colorScheme")
    func testSetThemeModeLight() {
        let vm = makeViewModel()

        vm.setThemeMode("light")
        #expect(vm.colorScheme == .light)
    }

    @Test("setThemeMode to system returns nil colorScheme")
    func testSetThemeModeSystem() {
        let vm = makeViewModel()

        vm.setThemeMode("dark")
        vm.setThemeMode("system")
        #expect(vm.colorScheme == nil)
    }

    // MARK: - Onboarding

    @Test("completeOnboarding sets flag to true")
    func testCompleteOnboarding() {
        let vm = makeViewModel()

        #expect(vm.isOnboardingComplete == false)

        vm.completeOnboarding()
        #expect(vm.isOnboardingComplete == true)
    }

    // MARK: - Bulk Update

    @Test("updatePreferences updates multiple fields")
    func testUpdatePreferences() {
        let vm = makeViewModel()

        vm.updatePreferences(language: "vi", currency: "VND", isOnboardingComplete: true)

        #expect(vm.language == "vi")
        #expect(vm.currency == "VND")
        #expect(vm.isOnboardingComplete == true)
    }

    @Test("updatePreferences with nil values preserves existing")
    func testUpdatePreferencesPartial() {
        let vm = makeViewModel()

        vm.setLanguage("vi")
        vm.updatePreferences(currency: "JPY")

        #expect(vm.language == "vi")  // Preserved
        #expect(vm.currency == "JPY")  // Updated
    }

    @Test("updatePreferences with all nil changes nothing")
    func testUpdatePreferencesNoop() {
        let vm = makeViewModel()

        vm.setLanguage("vi")
        vm.setCurrency("VND")
        vm.updatePreferences()

        #expect(vm.language == "vi")
        #expect(vm.currency == "VND")
    }

    // MARK: - Speech Language

    @Test("speechLanguage defaults to app language")
    func testSpeechLanguageDefault() {
        let vm = makeViewModel()
        #expect(vm.speechLanguage == "en")
    }

    @Test("setSpeechLanguage updates speechLanguage")
    func testSetSpeechLanguage() {
        let vm = makeViewModel()

        vm.setSpeechLanguage("es")
        #expect(vm.speechLanguage == "es")
    }

    @Test("setSpeechLanguage to nil falls back to app language")
    func testSetSpeechLanguageNil() {
        let vm = makeViewModel()

        vm.setLanguage("ja")
        vm.setSpeechLanguage(nil)
        #expect(vm.speechLanguage == "ja")
    }

    @Test("setLanguage resets speechLanguage when it matches new language")
    func testSetLanguageResetsSpeechLanguage() {
        let vm = makeViewModel()

        vm.setSpeechLanguage("vi")
        #expect(vm.speechLanguage == "vi")

        // Change app language to "vi" — speechLanguage should reset to follow
        vm.setLanguage("vi")
        #expect(vm.config.speechLanguage == nil)
        #expect(vm.speechLanguage == "vi")
    }

    @Test("setLanguage preserves speechLanguage when different")
    func testSetLanguagePreservesSpeechLanguage() {
        let vm = makeViewModel()

        vm.setSpeechLanguage("es")
        vm.setLanguage("ja")
        // speechLanguage is "es", app language changed to "ja" — should keep "es"
        #expect(vm.speechLanguage == "es")
    }

    // MARK: - formatCurrency

    @Test("formatCurrency uses current config")
    func testFormatCurrency() {
        let vm = makeViewModel()

        let formatted = vm.formatCurrency(1234.56)
        #expect(formatted.contains("$"))
        #expect(formatted.contains("1,234.56"))
    }

    @Test("formatCurrency updates after currency change")
    func testFormatCurrencyAfterChange() {
        let vm = makeViewModel()

        vm.setCurrency("VND")
        vm.setLanguage("vi")
        let formatted = vm.formatCurrency(1500000)
        #expect(formatted.contains("₫"))
    }

    // MARK: - Sequential Operations

    @Test("Multiple sequential updates work correctly")
    func testSequentialUpdates() {
        let vm = makeViewModel()

        vm.setLanguage("vi")
        vm.setCurrency("VND")
        vm.setThemeMode("dark")
        vm.completeOnboarding()

        #expect(vm.language == "vi")
        #expect(vm.currency == "VND")
        #expect(vm.themeMode == "dark")
        #expect(vm.isOnboardingComplete == true)
        #expect(vm.colorScheme == .dark)
    }

    // MARK: - System Language Sync

    @Test("detectSystemLanguage returns a supported language code")
    func testDetectSystemLanguage() {
        // Locale.preferredLanguages always has at least one entry on iOS/simulator
        let result = AppConfigViewModel.detectSystemLanguage()
        // The simulator typically runs in English, so we should get a supported language
        if let lang = result {
            let supported: Set<String> = ["en", "vi", "ja", "es"]
            #expect(supported.contains(lang))
        }
        // nil is acceptable if the system language is none of the supported ones
    }

    @Test("syncLanguageFromSystem does not overwrite when system matches config")
    func testSyncLanguageFromSystemNoChange() {
        let vm = makeViewModel()
        // detectSystemLanguage reads Locale.preferredLanguages which is affected
        // by the AppleLanguages UserDefaults key. Set it to a known value first.
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        let systemLang = AppConfigViewModel.detectSystemLanguage() ?? "en"
        // Set config to match system
        vm.setLanguage(systemLang)

        // Sync should not change anything
        vm.syncLanguageFromSystem()
        #expect(vm.language == systemLang)
    }

    @Test("updatePreferences with language syncs to system")
    func testUpdatePreferencesSyncsLanguage() {
        let vm = makeViewModel()
        // This should not crash and should update the config
        vm.updatePreferences(language: "ja", currency: "JPY", isOnboardingComplete: true)
        #expect(vm.language == "ja")
        #expect(vm.currency == "JPY")
        #expect(vm.isOnboardingComplete == true)
    }

    @Test("setLanguage writes to AppleLanguages UserDefaults key")
    func testSetLanguageWritesAppleLanguages() {
        let vm = makeViewModel()
        vm.setLanguage("vi")
        // Verify AppleLanguages was updated in standard UserDefaults
        let appleLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        #expect(appleLanguages?.first == "vi")
    }

    // MARK: - Reset All

    @Test("resetAll resets config to defaults")
    func testResetAllResetsConfig() {
        let vm = makeViewModel()

        // Modify everything
        vm.setLanguage("vi")
        vm.setCurrency("VND")
        vm.setThemeMode("dark")
        vm.completeOnboarding()

        #expect(vm.language == "vi")
        #expect(vm.currency == "VND")
        #expect(vm.themeMode == "dark")
        #expect(vm.isOnboardingComplete == true)

        // Reset
        vm.resetAll()

        #expect(vm.language == "en")
        #expect(vm.currency == "USD")
        #expect(vm.themeMode == "system")
        #expect(vm.isOnboardingComplete == false)
    }
}

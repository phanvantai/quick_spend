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
        #expect(formatted.contains("d"))
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
}

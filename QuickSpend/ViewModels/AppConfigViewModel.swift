import Foundation
import SwiftUI

/// Observable view model for managing app configuration state
@Observable
final class AppConfigViewModel {
    private(set) var config: AppConfig
    private let preferences = PreferencesService.shared

    var language: String { config.language }
    var currency: String { config.currency }
    var themeMode: String { config.themeMode }
    var isOnboardingComplete: Bool { config.isOnboardingComplete }

    var colorScheme: ColorScheme? { config.colorScheme }

    init() {
        self.config = PreferencesService.shared.getConfig()
    }

    func setLanguage(_ language: String) {
        config.language = language
        preferences.saveConfig(config)
    }

    func setCurrency(_ currency: String) {
        config.currency = currency
        preferences.saveConfig(config)
    }

    func setThemeMode(_ themeMode: String) {
        config.themeMode = themeMode
        preferences.saveConfig(config)
    }

    func completeOnboarding() {
        config.isOnboardingComplete = true
        preferences.saveConfig(config)
    }

    /// Bulk update (useful during onboarding)
    func updatePreferences(language: String? = nil, currency: String? = nil, isOnboardingComplete: Bool? = nil) {
        if let language { config.language = language }
        if let currency { config.currency = currency }
        if let isOnboardingComplete { config.isOnboardingComplete = isOnboardingComplete }
        preferences.saveConfig(config)
    }

    /// Format an amount using current config
    func formatCurrency(_ amount: Double) -> String {
        config.formatCurrency(amount)
    }
}

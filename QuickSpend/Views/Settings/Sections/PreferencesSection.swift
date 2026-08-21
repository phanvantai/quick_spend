import SwiftUI

/// Language + theme preferences (footer carries the app version).
struct PreferencesSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @Binding var activeSheet: SettingsSheet?

    var body: some View {
        Section {
            Button {
                activeSheet = .languagePicker
            } label: {
                SettingsRow(
                    icon: "globe",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("settings.language", appConfig.language),
                    subtitle: appConfig.config.languageDisplayName
                )
            }
            .tint(.primary)

            Button {
                activeSheet = .themePicker
            } label: {
                SettingsRow(
                    icon: "paintpalette.fill",
                    iconColor: AppTheme.accentPink,
                    title: L10n.tr("settings.theme", appConfig.language),
                    subtitle: themeDisplayName
                )
            }
            .tint(.primary)

        } header: {
            Text(L10n.tr("settings.preferences", appConfig.language))
        } footer: {
            Text(L10n.tr("settings.version", appConfig.language) + " \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.spacing8)
        }
    }

    private var themeDisplayName: String {
        switch appConfig.themeMode {
        case "light": return L10n.tr("settings.theme_light", appConfig.language)
        case "dark": return L10n.tr("settings.theme_dark", appConfig.language)
        default: return L10n.tr("settings.theme_system", appConfig.language)
        }
    }
}

import SwiftUI
import SwiftData

/// Language + theme preferences (footer carries the app version).
struct PreferencesSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var showLanguagePicker = false
    @State private var showThemePicker = false

    var body: some View {
        Section {
            Button {
                showLanguagePicker = true
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
                showThemePicker = true
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
        .sheet(isPresented: $showLanguagePicker) {
            PickerSheet(
                title: L10n.tr("settings.language", appConfig.language),
                doneText: L10n.tr("common.done", appConfig.language),
                items: LanguageOption.options,
                selectedId: appConfig.language,
                icon: { $0.flag },
                iconStyle: .custom,
                label: { $0.displayName },
                onSelect: { option in
                    appConfig.setLanguage(option.code)
                    CategoryService.updateCategoryNames(
                        language: option.code,
                        modelContext: modelContext
                    )
                    showLanguagePicker = false
                },
                onDone: { showLanguagePicker = false }
            )
        }
        .sheet(isPresented: $showThemePicker) {
            PickerSheet(
                title: L10n.tr("settings.theme", appConfig.language),
                doneText: L10n.tr("common.done", appConfig.language),
                items: ThemeOption.options(language: appConfig.language),
                selectedId: appConfig.themeMode,
                icon: { $0.icon },
                iconStyle: .sfSymbol(.primary),
                label: { $0.title },
                onSelect: { option in
                    appConfig.setThemeMode(option.code)
                    showThemePicker = false
                },
                onDone: { showThemePicker = false }
            )
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

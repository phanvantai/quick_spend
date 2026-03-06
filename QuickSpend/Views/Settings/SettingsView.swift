import SwiftUI
import SwiftData

/// Settings screen with grouped sections
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig

    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var showThemePicker = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Preferences
                Section(L10n.tr("settings.preferences", appConfig.language)) {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        settingsRow(
                            icon: "square.grid.2x2.fill",
                            iconColor: AppTheme.accentTeal,
                            title: L10n.tr("settings.categories", appConfig.language),
                            subtitle: L10n.tr("settings.categories_subtitle", appConfig.language)
                        )
                    }

                    NavigationLink {
                        RecurringListView()
                    } label: {
                        settingsRow(
                            icon: "repeat",
                            iconColor: AppTheme.accentPink,
                            title: L10n.tr("settings.recurring", appConfig.language),
                            subtitle: L10n.tr("settings.recurring_subtitle", appConfig.language)
                        )
                    }

                    Button {
                        showLanguagePicker = true
                    } label: {
                        settingsRow(
                            icon: "globe",
                            iconColor: AppTheme.primaryMint,
                            title: L10n.tr("settings.language", appConfig.language),
                            subtitle: appConfig.config.languageDisplayName
                        )
                    }
                    .tint(.primary)

                    Button {
                        showCurrencyPicker = true
                    } label: {
                        settingsRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: AppTheme.accentOrange,
                            title: L10n.tr("settings.currency", appConfig.language),
                            subtitle: "\(appConfig.config.currencySymbol) \(appConfig.currency)"
                        )
                    }
                    .tint(.primary)

                    Button {
                        showThemePicker = true
                    } label: {
                        settingsRow(
                            icon: "paintpalette.fill",
                            iconColor: AppTheme.accentPink,
                            title: L10n.tr("settings.theme", appConfig.language),
                            subtitle: themeDisplayName
                        )
                    }
                    .tint(.primary)
                }

                // Subscription
                Section {
                    if subscription.isPro {
                        settingsRow(
                            icon: "star.fill",
                            iconColor: AppTheme.accentOrange,
                            title: "Quick Spend Pro",
                            subtitle: L10n.tr("settings.pro_active", appConfig.language)
                        )
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            settingsRow(
                                icon: "star.fill",
                                iconColor: AppTheme.accentOrange,
                                title: L10n.tr("common.upgrade_pro", appConfig.language),
                                subtitle: L10n.tr("settings.unlock_features", appConfig.language)
                            )
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text(L10n.tr("settings.subscription", appConfig.language))
                } footer: {
                    Text(L10n.tr("settings.version", appConfig.language) + " \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppTheme.spacing8)
                }
            }
            .navigationTitle(L10n.tr("settings.title", appConfig.language))
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
            .sheet(isPresented: $showCurrencyPicker) {
                currencyPickerSheet
            }
            .sheet(isPresented: $showThemePicker) {
                themePickerSheet
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Settings Row

    private func settingsRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: icon,
                color: iconColor,
                size: 36,
                iconFont: .body
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Theme

    private var themeDisplayName: String {
        switch appConfig.themeMode {
        case "light": return L10n.tr("settings.theme_light", appConfig.language)
        case "dark": return L10n.tr("settings.theme_dark", appConfig.language)
        default: return L10n.tr("settings.theme_system", appConfig.language)
        }
    }

    // MARK: - Language Picker

    private var languagePickerSheet: some View {
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

    // MARK: - Currency Picker

    private var currencyPickerSheet: some View {
        PickerSheet(
            title: L10n.tr("settings.currency", appConfig.language),
            doneText: L10n.tr("common.done", appConfig.language),
            items: CurrencyOption.options,
            selectedId: appConfig.currency,
            icon: { $0.symbol },
            iconStyle: .plain(AppTheme.accentOrange),
            label: { $0.code },
            onSelect: { option in
                appConfig.setCurrency(option.code)
                showCurrencyPicker = false
            },
            onDone: { showCurrencyPicker = false }
        )
    }

    // MARK: - Theme Picker

    private var themePickerSheet: some View {
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

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

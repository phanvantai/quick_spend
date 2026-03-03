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
                Section(L10n.tr("settings.subscription", appConfig.language)) {
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
                }

                // About
                Section(L10n.tr("settings.about", appConfig.language)) {
                    aboutCard
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
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(iconColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(iconColor)
                }

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
        NavigationStack {
            List(LanguageOption.options) { option in
                Button {
                    appConfig.setLanguage(option.code)
                    // Re-seed categories in new language
                    CategoryService.updateCategoryNames(
                        language: option.code,
                        modelContext: modelContext
                    )
                    showLanguagePicker = false
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        Text(option.flag)
                            .font(.title2)
                        Text(option.displayName)
                            .font(.body)
                        Spacer()
                        if appConfig.language == option.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle(L10n.tr("settings.language", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) { showLanguagePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Currency Picker

    private var currencyPickerSheet: some View {
        NavigationStack {
            List(CurrencyOption.options) { option in
                Button {
                    appConfig.setCurrency(option.code)
                    showCurrencyPicker = false
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        Text(option.symbol)
                            .font(.title2.bold())
                            .frame(width: 32)
                        Text(option.code)
                            .font(.body)
                        Spacer()
                        if appConfig.currency == option.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle(L10n.tr("settings.currency", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) { showCurrencyPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Theme Picker

    private var themePickerSheet: some View {
        NavigationStack {
            List {
                themeOption(code: "system", icon: "circle.lefthalf.filled", title: L10n.tr("settings.theme_system", appConfig.language))
                themeOption(code: "light", icon: "sun.max.fill", title: L10n.tr("settings.theme_light", appConfig.language))
                themeOption(code: "dark", icon: "moon.fill", title: L10n.tr("settings.theme_dark", appConfig.language))
            }
            .navigationTitle(L10n.tr("settings.theme", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) { showThemePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func themeOption(code: String, icon: String, title: String) -> some View {
        Button {
            appConfig.setThemeMode(code)
            showThemePicker = false
        } label: {
            HStack(spacing: AppTheme.spacing12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)
                Text(title)
                    .font(.body)
                Spacer()
                if appConfig.themeMode == code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.primaryMint)
                }
            }
        }
        .tint(.primary)
    }

    // MARK: - About Card

    private var aboutCard: some View {
        HStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "wallet.bifold.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text("Quick Spend")
                    .font(.headline)
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("settings.track_easily", appConfig.language))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

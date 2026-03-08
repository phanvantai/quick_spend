import SwiftUI
import SwiftData

/// Settings screen with grouped sections
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @Environment(SubscriptionViewModel.self) private var subscription

    @Query private var transactions: [Transaction]

    @State private var showLanguagePicker = false
    @State private var showSpeechLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var showThemePicker = false
    @State private var showPaywall = false
    @State private var showPremiumStatus = false
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false
    @State private var isRestoring = false

    /// Currency cannot be changed once transactions exist to prevent data integrity issues
    private var isCurrencyLocked: Bool {
        !transactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Core features
                Section {
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
                        showSpeechLanguagePicker = true
                    } label: {
                        settingsRow(
                            icon: "mic.fill",
                            iconColor: AppTheme.adaptiveAccent(colorScheme),
                            title: L10n.tr("settings.speech_language", appConfig.language),
                            subtitle: appConfig.config.speechLanguageDisplayName
                        )
                    }
                    .tint(.primary)

                    Button {
                        if !isCurrencyLocked {
                            showCurrencyPicker = true
                        }
                    } label: {
                        HStack {
                            settingsRow(
                                icon: "dollarsign.circle.fill",
                                iconColor: isCurrencyLocked ? .gray : AppTheme.accentOrange,
                                title: L10n.tr("settings.currency", appConfig.language),
                                subtitle: "\(appConfig.config.currencySymbol) \(appConfig.currency)"
                            )
                            if isCurrencyLocked {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                    .disabled(isCurrencyLocked)
                } footer: {
                    VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                        Text(L10n.tr("settings.language_hint", appConfig.language))
                        if isCurrencyLocked {
                            Text(L10n.tr("settings.currency_locked_hint", appConfig.language))
                        }
                    }
                }

                // Subscription
                Section(L10n.tr("settings.subscription", appConfig.language)) {
                    if subscription.isPremium {
                        Button {
                            showPremiumStatus = true
                        } label: {
                            settingsRow(
                                icon: "star.fill",
                                iconColor: AppTheme.accentOrange,
                                title: L10n.tr("paywall.title", appConfig.language),
                                subtitle: L10n.tr("settings.premium_active", appConfig.language)
                            )
                        }
                        .tint(.primary)

                        NavigationLink {
                            FeatureRequestListView()
                        } label: {
                            settingsRow(
                                icon: "lightbulb.fill",
                                iconColor: AppTheme.adaptiveAccent(colorScheme),
                                title: L10n.tr("feature_request.title", appConfig.language),
                                subtitle: L10n.tr("settings.feature_request_subtitle", appConfig.language)
                            )
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            settingsRow(
                                icon: "star.fill",
                                iconColor: AppTheme.accentOrange,
                                title: L10n.tr("common.upgrade_premium", appConfig.language),
                                subtitle: L10n.tr("settings.unlock_features", appConfig.language)
                            )
                        }
                        .tint(.primary)

                        Button {
                            Task {
                                isRestoring = true
                                await subscription.restorePurchases()
                                isRestoring = false
                                restoreSuccess = subscription.isPremium
                                showRestoreAlert = true
                            }
                        } label: {
                            settingsRow(
                                icon: "arrow.clockwise",
                                iconColor: AppTheme.adaptiveAccent(colorScheme),
                                title: L10n.tr("paywall.restore", appConfig.language),
                                subtitle: L10n.tr("settings.restore_subtitle", appConfig.language)
                            )
                        }
                        .tint(.primary)
                        .disabled(isRestoring)
                    }
                }

                // Preferences
                Section {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        settingsRow(
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
                        settingsRow(
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
            .navigationTitle(L10n.tr("settings.title", appConfig.language))
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
            .sheet(isPresented: $showSpeechLanguagePicker) {
                speechLanguagePickerSheet
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
            .sheet(isPresented: $showPremiumStatus) {
                PremiumStatusSheet()
            }
            .alert(
                L10n.tr("paywall.restore", appConfig.language),
                isPresented: $showRestoreAlert
            ) {
                Button(L10n.tr("common.close", appConfig.language), role: .cancel) { }
            } message: {
                if restoreSuccess {
                    Text(L10n.tr("settings.restore_success", appConfig.language))
                } else {
                    Text(L10n.tr("paywall.restore_no_purchases", appConfig.language))
                }
            }
            .overlay {
                if isRestoring {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
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

    // MARK: - Speech Language Picker

    private var speechLanguagePickerSheet: some View {
        PickerSheet(
            title: L10n.tr("settings.speech_language", appConfig.language),
            doneText: L10n.tr("common.done", appConfig.language),
            items: LanguageOption.options,
            selectedId: appConfig.speechLanguage,
            icon: { $0.flag },
            iconStyle: .custom,
            label: { $0.displayName },
            onSelect: { option in
                // If same as app language, store nil (follow app language)
                if option.code == appConfig.language {
                    appConfig.setSpeechLanguage(nil)
                } else {
                    appConfig.setSpeechLanguage(option.code)
                }
                showSpeechLanguagePicker = false
            },
            onDone: { showSpeechLanguagePicker = false }
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

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
                Section("Preferences") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        settingsRow(
                            icon: "square.grid.2x2.fill",
                            iconColor: AppTheme.accentTeal,
                            title: "Categories",
                            subtitle: "Manage categories"
                        )
                    }

                    NavigationLink {
                        RecurringListView()
                    } label: {
                        settingsRow(
                            icon: "repeat",
                            iconColor: AppTheme.accentPink,
                            title: "Recurring",
                            subtitle: "Manage recurring expenses"
                        )
                    }

                    Button {
                        showLanguagePicker = true
                    } label: {
                        settingsRow(
                            icon: "globe",
                            iconColor: AppTheme.primaryMint,
                            title: "Language",
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
                            title: "Currency",
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
                            title: "Theme",
                            subtitle: themeDisplayName
                        )
                    }
                    .tint(.primary)
                }

                // Subscription
                Section("Subscription") {
                    if subscription.isPro {
                        settingsRow(
                            icon: "star.fill",
                            iconColor: AppTheme.accentOrange,
                            title: "Quick Spend Pro",
                            subtitle: "Active"
                        )
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            settingsRow(
                                icon: "star.fill",
                                iconColor: AppTheme.accentOrange,
                                title: "Upgrade to Pro",
                                subtitle: "Unlock unlimited features"
                            )
                        }
                        .tint(.primary)
                    }
                }

                // Privacy
                Section("Privacy") {
                    Toggle(isOn: Binding(
                        get: { appConfig.config.dataCollectionConsent },
                        set: { newValue in
                            appConfig.setDataCollectionConsent(newValue)
                            AnalyticsService.logDataCollectionToggled(enabled: newValue)
                            AnalyticsService.setDataCollectionConsentProperty(newValue)
                        }
                    )) {
                        settingsRow(
                            icon: "chart.bar.doc.horizontal",
                            iconColor: AppTheme.accentTeal,
                            title: "Help Improve AI",
                            subtitle: "Share anonymized data to improve parsing"
                        )
                    }
                    .tint(AppTheme.primaryMint)
                }

                // About
                Section("About") {
                    aboutCard
                }
            }
            .navigationTitle("Settings")
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
        case "light": return "Light"
        case "dark": return "Dark"
        default: return "System"
        }
    }

    // MARK: - Language Picker

    private var languagePickerSheet: some View {
        NavigationStack {
            List(LanguageOption.options) { option in
                Button {
                    appConfig.setLanguage(option.code)
                    // Re-seed categories in new language
                    CategoryService.updateSystemCategoryNames(
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
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showLanguagePicker = false }
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
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCurrencyPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Theme Picker

    private var themePickerSheet: some View {
        NavigationStack {
            List {
                themeOption(code: "system", icon: "circle.lefthalf.filled", title: "System")
                themeOption(code: "light", icon: "sun.max.fill", title: "Light")
                themeOption(code: "dark", icon: "moon.fill", title: "Dark")
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showThemePicker = false }
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
                Text("Track expenses easily")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

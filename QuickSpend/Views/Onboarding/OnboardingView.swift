import SwiftUI
import SwiftData

/// Single-screen onboarding: language + currency selection on one page
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var selectedLanguage = "en"
    @State private var selectedCurrency = "USD"
    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false

    private var selectedCurrencySymbol: String {
        CurrencyOption.options.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    private var selectedLanguageOption: LanguageOption {
        LanguageOption.options.first { $0.code == selectedLanguage } ?? LanguageOption.options[0]
    }

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacing32) {
                    Spacer(minLength: AppTheme.spacing40)

                    // App icon
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "wallet.bifold.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                        }

                    VStack(spacing: AppTheme.spacing8) {
                        Text("Quick Spend")
                            .font(.largeTitle.bold())
                        Text(L10n.tr("onboarding.tagline", selectedLanguage))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    // Language selection
                    SettingSelectionRow(
                        icon: selectedLanguageOption.flag,
                        iconColor: AppTheme.adaptiveAccent(colorScheme),
                        label: L10n.tr("settings.language", selectedLanguage),
                        value: selectedLanguageOption.displayName,
                        changeText: L10n.tr("onboarding.change", selectedLanguage),
                        action: { showLanguagePicker = true }
                    )
                    .padding(.horizontal, AppTheme.spacing24)

                    // Currency (auto-detected, tap to change)
                    SettingSelectionRow(
                        icon: selectedCurrencySymbol,
                        iconColor: AppTheme.accentOrange,
                        label: L10n.tr("onboarding.currency", selectedLanguage),
                        value: selectedCurrency,
                        changeText: L10n.tr("onboarding.change", selectedLanguage),
                        action: { showCurrencyPicker = true }
                    )
                    .padding(.horizontal, AppTheme.spacing24)

                    Spacer(minLength: AppTheme.spacing24)
                }
            }

            // Get Started button
            Button {
                completeOnboarding()
            } label: {
                HStack {
                    Text(L10n.tr("onboarding.get_started", selectedLanguage))
                    Image(systemName: "arrow.forward")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.adaptiveAccent(colorScheme))
            .padding(.horizontal, AppTheme.spacing24)
            .padding(.bottom, AppTheme.spacing16)
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .sheet(isPresented: $showCurrencyPicker) {
            currencyPickerSheet
        }
    }

    // MARK: - Language Picker Sheet

    private var languagePickerSheet: some View {
        PickerSheet(
            title: L10n.tr("settings.language", selectedLanguage),
            doneText: L10n.tr("common.done", selectedLanguage),
            items: LanguageOption.options,
            selectedId: selectedLanguage,
            icon: { $0.flag },
            iconStyle: .custom,
            label: { $0.displayName },
            onSelect: { option in
                selectedLanguage = option.code
                selectedCurrency = option.defaultCurrency
                showLanguagePicker = false
            },
            onDone: { showLanguagePicker = false }
        )
    }

    // MARK: - Currency Picker Sheet

    private var currencyPickerSheet: some View {
        PickerSheet(
            title: L10n.tr("onboarding.currency", selectedLanguage),
            doneText: L10n.tr("common.done", selectedLanguage),
            items: CurrencyOption.options,
            selectedId: selectedCurrency,
            icon: { $0.symbol },
            iconStyle: .plain(AppTheme.accentOrange),
            label: { $0.code },
            onSelect: { option in
                selectedCurrency = option.code
                showCurrencyPicker = false
            },
            onDone: { showCurrencyPicker = false }
        )
    }

    // MARK: - Actions

    private func completeOnboarding() {
        appConfig.updatePreferences(
            language: selectedLanguage,
            currency: selectedCurrency,
            isOnboardingComplete: true
        )

        CategoryService.seedCategoriesIfNeeded(
            language: selectedLanguage,
            modelContext: modelContext
        )

        // No anchor seed — BalanceCard's "Set up balance" CTA is the natural
        // empty state. The user enters their starting amount from Home or
        // Settings when ready. Auto-seeding to 0 caused multi-row conflicts
        // when a second device synced a real anchor from a different setup
        // moment, and CloudKit can't enforce `@Attribute(.unique)`.

        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}

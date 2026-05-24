import SwiftUI
import SwiftData

/// Three-step onboarding: language/currency → starting balance → Try Siri demo.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var step: Int = 0
    @State private var selectedLanguage = "en"
    @State private var selectedCurrency = "USD"
    @State private var balanceText: String = ""
    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var hasInitializedPreferences = false

    private var selectedCurrencySymbol: String {
        CurrencyOption.options.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    private var selectedLanguageOption: LanguageOption {
        LanguageOption.options.first { $0.code == selectedLanguage } ?? LanguageOption.options[0]
    }

    /// Working config used to format/parse the amount in the balance step before
    /// the real `AppConfig` is committed by completeOnboarding.
    private var draftConfig: AppConfig {
        AppConfig(language: selectedLanguage, currency: selectedCurrency)
    }

    private var parsedBalance: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return draftConfig.parseAmount(trimmed)
    }

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                preferencesStep.tag(0)
                balanceStep.tag(1)
                trySiriStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.springSmooth, value: step)

            primaryButton
                .padding(.horizontal, AppTheme.spacing24)
                .padding(.bottom, AppTheme.spacing16)
        }
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
        .sheet(isPresented: $showCurrencyPicker) {
            currencyPickerSheet
        }
        .onAppear {
            initializePreferencesIfNeeded()
        }
    }

    // MARK: - Step 0: Preferences

    private var preferencesStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing32) {
                Spacer(minLength: AppTheme.spacing40)

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
                        .font(Typography.title)
                    Text(L10n.tr("onboarding.tagline", selectedLanguage))
                        .font(Typography.titleMedium)
                        .foregroundStyle(.secondary)
                }

                SettingSelectionRow(
                    icon: selectedLanguageOption.flag,
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    label: L10n.tr("settings.language", selectedLanguage),
                    value: selectedLanguageOption.displayName,
                    changeText: L10n.tr("onboarding.change", selectedLanguage),
                    action: { showLanguagePicker = true }
                )
                .padding(.horizontal, AppTheme.spacing24)

                SettingSelectionRow(
                    icon: selectedCurrencySymbol,
                    iconColor: AppTheme.accentOrange,
                    label: L10n.tr("onboarding.currency", selectedLanguage),
                    value: selectedCurrency,
                    changeText: L10n.tr("onboarding.change", selectedLanguage),
                    action: { showCurrencyPicker = true }
                )
                .padding(.horizontal, AppTheme.spacing24)

                Spacer(minLength: AppTheme.spacing40)
            }
        }
    }

    // MARK: - Step 1: Starting Balance

    private var balanceStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing24) {
                Spacer(minLength: AppTheme.spacing24)

                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: AppTheme.spacing8) {
                    Text(L10n.tr("onboarding.balance_title", selectedLanguage))
                        .font(Typography.title)
                        .multilineTextAlignment(.center)
                    Text(L10n.tr("onboarding.balance_subtitle", selectedLanguage))
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.spacing24)
                }

                HStack {
                    TextField(
                        L10n.tr("balance.edit_placeholder", selectedLanguage),
                        text: $balanceText
                    )
                    .keyboardType(.decimalPad)
                    .font(Typography.title)
                    .multilineTextAlignment(.center)

                    Text(draftConfig.currency)
                        .font(Typography.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppTheme.spacing24)
                .padding(.vertical, AppTheme.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, AppTheme.spacing24)

                Button {
                    balanceText = ""
                    withAnimation(.springSmooth) { step = 2 }
                } label: {
                    Text(L10n.tr("onboarding.balance_skip", selectedLanguage))
                        .font(Typography.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer(minLength: AppTheme.spacing24)
            }
            .onChange(of: balanceText) {
                let formatted = draftConfig.formatAmountInput(balanceText)
                if formatted != balanceText { balanceText = formatted }
            }
        }
    }

    // MARK: - Step 2: Try Siri

    private var trySiriStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing24) {
                Spacer(minLength: AppTheme.spacing24)

                ModalGradientHero(
                    icon: "waveform",
                    gradient: LinearGradient(
                        colors: [Color.purple, Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    glowColor: Color.purple,
                    animatedSymbol: true
                )

                VStack(spacing: AppTheme.spacing8) {
                    Text(L10n.tr("siri_promo.title", selectedLanguage))
                        .font(Typography.title)
                        .multilineTextAlignment(.center)
                    Text(L10n.tr("siri_promo.subtitle", selectedLanguage))
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.spacing24)
                }

                VStack(spacing: AppTheme.spacing12) {
                    phraseCard(key: "siri_promo.example_1", icon: "mic.fill")
                    phraseCard(key: "siri_promo.example_2", icon: "sparkles")
                }
                .padding(.horizontal, AppTheme.spacing24)

                Text(L10n.tr("siri_promo.footnote", selectedLanguage))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacing24)

                Spacer(minLength: AppTheme.spacing24)
            }
        }
    }

    private func phraseCard(key: String, icon: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: icon)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            Text(L10n.tr(key, selectedLanguage))
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(AppTheme.spacing12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            switch step {
            case 0:
                withAnimation(.springSmooth) { step = 1 }
            case 1:
                withAnimation(.springSmooth) { step = 2 }
            default:
                completeOnboarding()
            }
        } label: {
            HStack {
                Text(step == 2
                     ? L10n.tr("onboarding.get_started", selectedLanguage)
                     : L10n.tr("onboarding.continue", selectedLanguage))
                Image(systemName: "arrow.forward")
            }
            .font(Typography.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(AppTheme.adaptiveAccent(colorScheme))
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

        // Seed a BalanceAnchor if the user entered an amount on step 1. Skipped
        // step leaves no anchor, which makes BalanceHero render its setup CTA.
        if let amount = parsedBalance {
            let anchor = BalanceAnchor(
                openingBalance: amount,
                anchorDate: Date()
            )
            modelContext.insert(anchor)
            try? modelContext.save()
        }

        onComplete()
    }

    private func initializePreferencesIfNeeded() {
        guard !hasInitializedPreferences else { return }
        hasInitializedPreferences = true

        let language = AppConfigViewModel.initialOnboardingLanguage()
        selectedLanguage = language
        selectedCurrency = LanguageOption.defaultCurrency(for: language)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self], inMemory: true)
        .environment(AppConfigViewModel())
}

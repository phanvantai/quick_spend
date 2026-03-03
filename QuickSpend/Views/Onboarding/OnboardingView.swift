import SwiftUI
import SwiftData

/// Single-screen onboarding: language + currency selection on one page
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
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
                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack(spacing: AppTheme.spacing12) {
                            Circle()
                                .fill(AppTheme.primaryMint)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Text(selectedLanguageOption.flag)
                                        .font(.title3)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("settings.language", selectedLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(selectedLanguageOption.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Text(L10n.tr("onboarding.change", selectedLanguage))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                        .padding(AppTheme.spacing16)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .fill(Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.spacing24)

                    // Currency (auto-detected, tap to change)
                    Button {
                        showCurrencyPicker = true
                    } label: {
                        HStack(spacing: AppTheme.spacing12) {
                            Circle()
                                .fill(AppTheme.accentOrange)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Text(selectedCurrencySymbol)
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("onboarding.currency", selectedLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(selectedCurrency)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Text(L10n.tr("onboarding.change", selectedLanguage))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                        .padding(AppTheme.spacing16)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .fill(Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .buttonStyle(.plain)
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
            .tint(AppTheme.primaryMint)
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
        NavigationStack {
            List(LanguageOption.options) { option in
                Button {
                    selectedLanguage = option.code
                    selectedCurrency = option.defaultCurrency
                    showLanguagePicker = false
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        Text(option.flag)
                            .font(.title2)
                            .frame(width: 32)
                        Text(option.displayName)
                            .font(.body)
                        Spacer()
                        if selectedLanguage == option.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle(L10n.tr("settings.language", selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", selectedLanguage)) {
                        showLanguagePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Currency Picker Sheet

    private var currencyPickerSheet: some View {
        NavigationStack {
            List(CurrencyOption.options) { option in
                Button {
                    selectedCurrency = option.code
                    showCurrencyPicker = false
                } label: {
                    HStack(spacing: AppTheme.spacing12) {
                        Circle()
                            .fill(AppTheme.accentOrange)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(option.symbol)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                        Text(option.code)
                            .font(.body)
                        Spacer()
                        if selectedCurrency == option.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primaryMint)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle(L10n.tr("onboarding.currency", selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", selectedLanguage)) {
                        showCurrencyPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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

        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}

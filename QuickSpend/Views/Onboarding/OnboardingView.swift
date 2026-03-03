import SwiftUI
import SwiftData

/// Single-screen onboarding: language + currency selection on one page
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var selectedLanguage = "en"
    @State private var selectedCurrency = "USD"
    @State private var showCurrencyPicker = false

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
                    VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                        ForEach(LanguageOption.options) { option in
                            OptionCard(
                                isSelected: selectedLanguage == option.code,
                                leading: Text(option.flag).font(.largeTitle),
                                title: option.displayName
                            ) {
                                selectedLanguage = option.code
                                selectedCurrency = option.defaultCurrency
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing24)

                    // Currency (auto-detected, tap to change)
                    Button {
                        showCurrencyPicker = true
                    } label: {
                        HStack(spacing: AppTheme.spacing12) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accentOrange)
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
        .sheet(isPresented: $showCurrencyPicker) {
            currencyPickerSheet
        }
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
                        Text(option.symbol)
                            .font(.title2.bold())
                            .frame(width: 32)
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

// MARK: - Option Card

struct OptionCard: View {
    let isSelected: Bool
    let leading: AnyView
    let title: String
    let action: () -> Void

    init(isSelected: Bool, leading: some View, title: String, action: @escaping () -> Void) {
        self.isSelected = isSelected
        self.leading = AnyView(leading)
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacing16) {
                leading
                    .frame(width: 48)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.primaryMint)
                        .font(.title3)
                }
            }
            .padding(AppTheme.spacing12)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(isSelected ? AppTheme.primaryMint.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.primaryMint : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}

import SwiftUI
import SwiftData

/// Multi-step onboarding: Welcome → Language → Currency → Done
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var currentPage = 0
    @State private var selectedLanguage = "en"
    @State private var selectedCurrency = "USD"

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Page indicators
            pageIndicator
                .padding(.top, AppTheme.spacing16)

            // Pages
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                languagePage.tag(1)
                currencyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Navigation buttons
            navigationButtons
                .padding(AppTheme.spacing16)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: AppTheme.spacing4) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? AppTheme.primaryMint : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? 32 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing32) {
                Spacer(minLength: AppTheme.spacing40)

                // App icon
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 140, height: 140)
                    .overlay {
                        Image(systemName: "wallet.bifold.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: AppTheme.spacing12) {
                    Text("Quick Spend")
                        .font(.largeTitle.bold())
                    Text("Track expenses with your voice")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: AppTheme.spacing16) {
                    featureRow(
                        icon: "mic.fill",
                        title: "AI Voice Input",
                        description: "Speak to add expenses naturally",
                        color: AppTheme.accentOrange
                    )
                    featureRow(
                        icon: "globe",
                        title: "6 Languages",
                        description: "English, Vietnamese, Japanese, Korean, Thai, Spanish",
                        color: AppTheme.accentTeal
                    )
                    featureRow(
                        icon: "chart.bar.fill",
                        title: "Smart Reports",
                        description: "Charts, calendar view, and insights",
                        color: AppTheme.accentPink
                    )
                }
                .padding(.horizontal, AppTheme.spacing8)

                Spacer(minLength: AppTheme.spacing40)
            }
            .padding(.horizontal, AppTheme.spacing24)
        }
    }

    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: AppTheme.spacing16) {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(color.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Language Page

    private var languagePage: some View {
        VStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                .padding(.top, AppTheme.spacing24)

            Text("Choose Language")
                .font(.title.bold())
            Text("You can change this later in settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: AppTheme.spacing8) {
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
            }
        }
    }

    // MARK: - Currency Page

    private var currencyPage: some View {
        VStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.accentGradient)
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                .padding(.top, AppTheme.spacing24)

            Text("Choose Currency")
                .font(.title.bold())
            Text("You can change this later in settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: AppTheme.spacing8) {
                    ForEach(CurrencyOption.options) { option in
                        OptionCard(
                            isSelected: selectedCurrency == option.code,
                            leading: Text(option.symbol)
                                .font(.title.bold())
                                .frame(width: 40),
                            title: option.code
                        ) {
                            selectedCurrency = option.code
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacing24)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: AppTheme.spacing16) {
            if currentPage > 0 {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                if currentPage < 2 {
                    withAnimation { currentPage += 1 }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack {
                    Text(currentPage == 2 ? "Get Started" : "Next")
                    Image(systemName: currentPage == 2 ? "checkmark" : "arrow.forward")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.primaryMint)
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        // Save preferences
        appConfig.updatePreferences(
            language: selectedLanguage,
            currency: selectedCurrency,
            isOnboardingComplete: true
        )

        // Seed categories
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

import SwiftUI

/// Paywall screen showing subscription options
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing24) {
                    // Hero
                    heroSection

                    // Features
                    featuresSection

                    // Pricing
                    pricingSection

                    // Legal
                    legalSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing32)
            }
            .navigationTitle("Quick Spend Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task {
                            await subscription.restorePurchases()
                            if subscription.isPro { dismiss() }
                        }
                    }
                    .font(.caption)
                }
            }
            .overlay {
                if isPurchasing || subscription.isLoading {
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

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }

            Text("Unlock Full Power")
                .font(.title2.bold())

            Text("Remove limits and get the most out of Quick Spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacing16)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            featureRow(
                icon: "mic.fill",
                color: AppTheme.primaryMint,
                title: "Unlimited AI Voice Input",
                subtitle: "No daily limit on AI-powered expense parsing"
            )
            featureRow(
                icon: "repeat",
                color: AppTheme.accentPink,
                title: "Unlimited Recurring Templates",
                subtitle: "Create as many recurring expenses as you need"
            )
            featureRow(
                icon: "chart.bar.fill",
                color: AppTheme.accentOrange,
                title: "Extended Reports",
                subtitle: "View reports for any time range"
            )
            featureRow(
                icon: "heart.fill",
                color: AppTheme.error,
                title: "Support Development",
                subtitle: "Help us build better features for you"
            )
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: AppTheme.spacing12) {
            // Yearly (best value)
            Button {
                purchase(yearly: true)
            } label: {
                VStack(spacing: AppTheme.spacing4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Yearly")
                                .font(.headline)
                            Text("$\(String(format: "%.2f", AppConstants.subscriptionYearlyPriceUSD))/year")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Best Value")
                            .font(.caption.bold())
                            .padding(.horizontal, AppTheme.spacing8)
                            .padding(.vertical, AppTheme.spacing4)
                            .background {
                                Capsule()
                                    .fill(AppTheme.primaryMint.opacity(0.2))
                            }
                            .foregroundStyle(AppTheme.primaryMint)
                    }
                }
                .padding(AppTheme.spacing16)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.primaryMint, lineWidth: 2)
                }
            }
            .tint(.primary)

            // Monthly
            Button {
                purchase(yearly: false)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Monthly")
                            .font(.headline)
                        Text("$\(String(format: "%.2f", AppConstants.subscriptionMonthlyPriceUSD))/month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(AppTheme.spacing16)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
            .tint(.primary)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: AppTheme.spacing4) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.spacing16) {
                if let termsURL = URL(string: AppConstants.termsOfUseUrl) {
                    Link("Terms of Use", destination: termsURL)
                        .font(.caption2)
                }
                if let privacyURL = URL(string: AppConstants.privacyPolicyUrl) {
                    Link("Privacy Policy", destination: privacyURL)
                        .font(.caption2)
                }
            }
        }
        .padding(.top, AppTheme.spacing8)
    }

    // MARK: - Actions

    private func purchase(yearly: Bool) {
        isPurchasing = true
        Task {
            let success = yearly
                ? await subscription.purchaseYearly()
                : await subscription.purchaseMonthly()
            isPurchasing = false
            if success { dismiss() }
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionViewModel())
}

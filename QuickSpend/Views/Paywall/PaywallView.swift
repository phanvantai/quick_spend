import SwiftUI

/// Paywall screen showing subscription options
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing24) {
                    heroSection
                    featuresSection
                    pricingSection
                    legalSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing32)
            }
            .navigationTitle("Quick Spend Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.tr("paywall.restore", appConfig.language)) {
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

            Text(L10n.tr("paywall.title", appConfig.language))
                .font(.title2.bold())

            Text(L10n.tr("paywall.subtitle", appConfig.language))
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
                title: L10n.tr("paywall.feature_voice", appConfig.language),
                subtitle: L10n.tr("paywall.feature_voice_desc", appConfig.language)
            )
            featureRow(
                icon: "repeat",
                color: AppTheme.accentPink,
                title: L10n.tr("paywall.feature_recurring", appConfig.language),
                subtitle: L10n.tr("paywall.feature_recurring_desc", appConfig.language)
            )
            featureRow(
                icon: "chart.bar.fill",
                color: AppTheme.accentOrange,
                title: L10n.tr("paywall.feature_reports", appConfig.language),
                subtitle: L10n.tr("paywall.feature_reports_desc", appConfig.language)
            )
            featureRow(
                icon: "heart.fill",
                color: AppTheme.error,
                title: L10n.tr("paywall.feature_support", appConfig.language),
                subtitle: L10n.tr("paywall.feature_support_desc", appConfig.language)
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
                            Text(L10n.tr("paywall.plan_yearly", appConfig.language))
                                .font(.headline)
                            Text("$\(String(format: "%.2f", AppConstants.subscriptionYearlyPriceUSD))/\(L10n.tr("paywall.per_year", appConfig.language))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(L10n.tr("paywall.best_value", appConfig.language))
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
                        Text(L10n.tr("paywall.plan_monthly", appConfig.language))
                            .font(.headline)
                        Text("$\(String(format: "%.2f", AppConstants.subscriptionMonthlyPriceUSD))/\(L10n.tr("paywall.per_month", appConfig.language))")
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
            Text(L10n.tr("paywall.auto_renew", appConfig.language))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.spacing16) {
                if let termsURL = URL(string: AppConstants.termsOfUseUrl) {
                    Link(L10n.tr("paywall.terms", appConfig.language), destination: termsURL)
                        .font(.caption2)
                }
                if let privacyURL = URL(string: AppConstants.privacyPolicyUrl) {
                    Link(L10n.tr("paywall.privacy", appConfig.language), destination: privacyURL)
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
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

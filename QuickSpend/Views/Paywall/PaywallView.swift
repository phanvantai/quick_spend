import SwiftUI

/// Paywall screen showing subscription options
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var isPurchasing = false
    @State private var selectedPlan: PlanType = .yearly
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false

    private enum PlanType { case monthly, yearly }

    /// Accent color that adapts to color scheme for readability
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color {
        colorScheme == .dark ? AppTheme.primaryLight : AppTheme.primaryMint
    }

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
            .navigationTitle(L10n.tr("paywall.title", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.tr("paywall.restore", appConfig.language)) {
                        Task {
                            await subscription.restorePurchases()
                            restoreSuccess = subscription.isPremium
                            if restoreSuccess {
                                dismiss()
                            } else {
                                showRestoreAlert = true
                            }
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
            .alert(
                L10n.tr("paywall.restore", appConfig.language),
                isPresented: $showRestoreAlert
            ) {
                Button(L10n.tr("common.close", appConfig.language), role: .cancel) { }
            } message: {
                Text(L10n.tr("paywall.restore_no_purchases", appConfig.language))
            }
            .tint(accent)
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

    // MARK: - Features Comparison

    private var featuresSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.tr("paywall.features", appConfig.language))
                    .font(.subheadline.bold())
                Spacer()
                Text(L10n.tr("paywall.free", appConfig.language))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 60)
                Text(L10n.tr("paywall.premium_label", appConfig.language))
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                    .frame(width: 60)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing12)

            Divider()

            comparisonRow(
                icon: "mic.fill",
                color: AppTheme.primaryLight,
                title: L10n.tr("paywall.feature_voice", appConfig.language),
                freeValue: "\(AppConstants.freeTierGeminiLimit)/\(L10n.tr("paywall.per_day", appConfig.language))",
                premiumValue: L10n.tr("paywall.unlimited", appConfig.language)
            )

            Divider().padding(.leading, 56)

            comparisonRow(
                icon: "repeat",
                color: AppTheme.accentPink,
                title: L10n.tr("paywall.feature_recurring", appConfig.language),
                freeValue: "\(AppConstants.freeTierRecurringTemplatesLimit)",
                premiumValue: L10n.tr("paywall.unlimited", appConfig.language)
            )

            Divider().padding(.leading, 56)

            comparisonRow(
                icon: "chart.bar.fill",
                color: AppTheme.accentOrange,
                title: L10n.tr("paywall.feature_reports", appConfig.language),
                freeValue: "\(AppConstants.freeTierReportDaysLimit) \(L10n.tr("paywall.days", appConfig.language))",
                premiumValue: L10n.tr("paywall.all_time", appConfig.language)
            )

            Divider().padding(.leading, 56)

            comparisonRow(
                icon: "lightbulb.fill",
                color: AppTheme.accentTeal,
                title: L10n.tr("paywall.feature_requests_label", appConfig.language),
                freeValue: nil,
                premiumValue: nil
            )
        }
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func comparisonRow(
        icon: String,
        color: Color,
        title: String,
        freeValue: String?,
        premiumValue: String?
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.15))
                }

            Text(title)
                .font(.caption)
                .lineLimit(2)

            Spacer()

            if let freeValue {
                Text(freeValue)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 60)
            } else {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(width: 60)
            }

            if let premiumValue {
                Text(premiumValue)
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                    .frame(width: 60)
            } else {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing8)
    }

    // MARK: - Pricing

    private var yearlyPriceText: String {
        if let price = subscription.yearlyPriceDisplay {
            return "\(price)/\(L10n.tr("paywall.per_year", appConfig.language))"
        }
        return "$\(String(format: "%.2f", AppConstants.subscriptionYearlyPriceUSD))/\(L10n.tr("paywall.per_year", appConfig.language))"
    }

    private var monthlyPriceText: String {
        if let price = subscription.monthlyPriceDisplay {
            return "\(price)/\(L10n.tr("paywall.per_month", appConfig.language))"
        }
        return "$\(String(format: "%.2f", AppConstants.subscriptionMonthlyPriceUSD))/\(L10n.tr("paywall.per_month", appConfig.language))"
    }

    private var pricingSection: some View {
        VStack(spacing: AppTheme.spacing16) {
            // Plan selection
            VStack(spacing: AppTheme.spacing8) {
                // Yearly
                planCard(
                    plan: .yearly,
                    title: L10n.tr("paywall.plan_yearly", appConfig.language),
                    price: yearlyPriceText,
                    badge: L10n.tr("paywall.best_value", appConfig.language)
                )

                // Monthly
                planCard(
                    plan: .monthly,
                    title: L10n.tr("paywall.plan_monthly", appConfig.language),
                    price: monthlyPriceText,
                    badge: nil
                )
            }

            // Upgrade button
            Button {
                purchase(yearly: selectedPlan == .yearly)
            } label: {
                Text(L10n.tr("paywall.upgrade_now", appConfig.language))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing16)
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .fill(accent)
                    }
            }
        }
        .task {
            if subscription.monthlyPriceDisplay == nil {
                await subscription.loadOfferings()
            }
        }
    }

    private func planCard(plan: PlanType, title: String, price: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(.easeQuick) {
                selectedPlan = plan
            }
        } label: {
            HStack {
                // Radio indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? accent : .secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, AppTheme.spacing8)
                        .padding(.vertical, AppTheme.spacing4)
                        .background {
                            Capsule()
                                .fill(accent.opacity(0.15))
                        }
                        .foregroundStyle(accent)
                }
            }
            .padding(AppTheme.spacing16)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? accent : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                            .fill(isSelected ? accent.opacity(0.05) : .clear)
                    }
            }
        }
        .tint(.primary)
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

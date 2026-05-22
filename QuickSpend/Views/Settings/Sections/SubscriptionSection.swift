import SwiftUI

/// Premium / restore purchases / feature requests.
struct SubscriptionSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var showPaywall = false
    @State private var showPremiumStatus = false
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false
    @State private var isRestoring = false

    /// Bound to parent so the loading overlay can sit on the whole screen.
    @Binding var globalIsRestoring: Bool

    var body: some View {
        Section(L10n.tr("settings.subscription", appConfig.language)) {
            if subscription.isPremium {
                Button {
                    showPremiumStatus = true
                } label: {
                    SettingsRow(
                        icon: "star.fill",
                        iconColor: AppTheme.accentOrange,
                        title: L10n.tr("paywall.title", appConfig.language),
                        subtitle: L10n.tr("settings.premium_active", appConfig.language)
                    )
                }
                .tint(.primary)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    SettingsRow(
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
                        globalIsRestoring = true
                        await subscription.restorePurchases()
                        isRestoring = false
                        globalIsRestoring = false
                        restoreSuccess = subscription.isPremium
                        showRestoreAlert = true
                    }
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        iconColor: AppTheme.adaptiveAccent(colorScheme),
                        title: L10n.tr("paywall.restore", appConfig.language),
                        subtitle: L10n.tr("settings.restore_subtitle", appConfig.language)
                    )
                }
                .tint(.primary)
                .disabled(isRestoring)
            }

            NavigationLink {
                FeatureRequestListView()
            } label: {
                SettingsRow(
                    icon: "lightbulb.fill",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("feature_request.title", appConfig.language),
                    subtitle: L10n.tr("settings.feature_request_subtitle", appConfig.language)
                )
            }
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
    }
}

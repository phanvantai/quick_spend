import SwiftUI
import UIKit

/// One-time 4.2 modal introducing bank alerts. Shown after the Voice Shortcut
/// promo, to VND users only. "Set up now" installs the ready-made shortcut when
/// one is published, else asks Home to open the setup guide.
struct BankAlertsWhatsNewModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }

    var body: some View {
        ModalTemplate(
            title: t("bank_alert.whats_new.title"),
            subtitle: t("bank_alert.whats_new.subtitle"),
            primary: ModalCTA(
                label: t(BankAlertShortcut.installURL(for: language) == nil ? "bank_alert.whats_new.setup" : "bank_alert.quick_install.button"),
                icon: "bolt.fill",
                action: setUp
            ),
            secondary: ModalCTA(label: t("bank_alert.whats_new.later"), action: later),
            hero: {
                ModalGradientHero(
                    icon: "building.columns.fill",
                    gradient: AppTheme.primaryGradient,
                    glowColor: AppTheme.primaryGreen,
                    animatedSymbol: false
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(t("bank_alert.whats_new.title"))
            },
            content: {
                VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                    benefit(icon: "bell.badge.fill", key: "bank_alert.whats_new.benefit_1")
                    benefit(icon: "text.magnifyingglass", key: "bank_alert.whats_new.benefit_2")
                    benefit(icon: "lock.shield.fill", key: "bank_alert.whats_new.benefit_3")
                }
                .padding(.horizontal, AppTheme.spacing24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
    }

    private func benefit(icon: String, key: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: icon)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 24, height: 24)
                .padding(.top, 1)
            Text(t(key))
                .font(Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func setUp() {
        appConfig.markBankAlertsWhatsNewSeen()
        if let url = BankAlertShortcut.installURL(for: language) {
            UIApplication.shared.open(url)
        } else {
            appConfig.bankAlertSetupRequested = true
        }
        dismiss()
    }

    private func later() {
        appConfig.markBankAlertsWhatsNewSeen()
        dismiss()
    }
}

/// Home card suggesting bank-alert setup until the first alert arrives.
struct BankAlertSetupCard: View {
    let language: String
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: AppTheme.spacing12) {
                    CategoryIconBadge(iconName: "building.columns.fill", color: AppTheme.primaryLight, size: 40, iconFont: .body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("bank_alert.card.title", language))
                            .font(Typography.bodyEmphasized)
                            .foregroundStyle(.primary)
                        Text(L10n.tr("bank_alert.card.subtitle", language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.tr("bank_alert.card.cta", language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryLight)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("common.close", language))
        }
        .padding(AppTheme.spacing12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

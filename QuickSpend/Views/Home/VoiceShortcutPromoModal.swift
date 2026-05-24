import SwiftUI
import UIKit

/// One-time modal introducing the Siri/Shortcuts voice expense flow.
/// Deep-links the user into Shortcuts.app to install the pre-built shortcut.
/// Fires once per install regardless of upgrade vs fresh path.
struct VoiceShortcutPromoModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    var body: some View {
        ModalTemplate(
            title: L10n.tr("voice_shortcut.promo_title", appConfig.language),
            subtitle: L10n.tr("voice_shortcut.promo_subtitle", appConfig.language),
            primary: ModalCTA(
                label: L10n.tr("voice_shortcut.install_cta", appConfig.language),
                icon: "arrow.up.right.square.fill",
                action: installShortcut
            ),
            secondary: ModalCTA(
                label: L10n.tr("voice_shortcut.later_cta", appConfig.language),
                action: dismissAndMarkSeen
            ),
            hero: {
                ModalGradientHero(
                    icon: "mic.fill",
                    gradient: AppTheme.primaryGradient,
                    glowColor: AppTheme.primaryGreen,
                    animatedSymbol: false
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("voice_shortcut.promo_title", appConfig.language))
            },
            content: {
                VStack(spacing: AppTheme.spacing24) {
                    siriTip
                    benefits
                }
            }
        )
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            benefitRow(key: "voice_shortcut.promo_benefit_1")
            benefitRow(key: "voice_shortcut.promo_benefit_2")
            benefitRow(key: "voice_shortcut.promo_benefit_3")
        }
        .padding(.horizontal, AppTheme.spacing24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitRow(key: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(L10n.tr(key, appConfig.language))
                .font(Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var siriTip: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: "waveform")
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

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("voice_shortcut.siri_tip_title", appConfig.language))
                    .font(Typography.bodyEmphasized)
                    .foregroundStyle(.primary)
                Text(L10n.tr("voice_shortcut.siri_tip_body", appConfig.language))
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacing12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .padding(.horizontal, AppTheme.spacing24)
    }

    private func installShortcut() {
        if let url = VoiceShortcut.installURL(for: appConfig.language) {
            UIApplication.shared.open(url)
        }
        dismissAndMarkSeen()
    }

    private func dismissAndMarkSeen() {
        appConfig.markVoiceShortcutPromoSeen()
        dismiss()
    }
}

#Preview("English") {
    VoiceShortcutPromoModal()
        .environment(AppConfigViewModel())
}

#Preview("Vietnamese Dark") {
    let vm = AppConfigViewModel()
    vm.setLanguage("vi")
    return VoiceShortcutPromoModal()
        .environment(vm)
        .preferredColorScheme(.dark)
}

import SwiftUI

/// One-time modal that teaches the user the "Hey Siri, …" trigger phrases —
/// no setup required, works out of the box. Sits between the Balance modal
/// and the Voice Shortcut promo in the post-launch sequence: Siri is the
/// universal fallback, Shortcuts is the one-tap optimisation on top.
struct SiriPromoModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    var body: some View {
        ModalTemplate(
            title: L10n.tr("siri_promo.title", appConfig.language),
            subtitle: L10n.tr("siri_promo.subtitle", appConfig.language),
            primary: ModalCTA(
                label: L10n.tr("siri_promo.got_it_cta", appConfig.language),
                action: dismissAndMarkSeen
            ),
            secondary: nil,
            hero: {
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("siri_promo.title", appConfig.language))
            },
            content: {
                VStack(spacing: AppTheme.spacing24) {
                    phrases
                    footnote
                }
            }
        )
    }

    private var phrases: some View {
        VStack(spacing: AppTheme.spacing12) {
            phraseCard(key: "siri_promo.example_1", icon: "mic.fill")
            phraseCard(key: "siri_promo.example_2", icon: "sparkles")
        }
        .padding(.horizontal, AppTheme.spacing24)
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

            Text(L10n.tr(key, appConfig.language))
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

    private var footnote: some View {
        Text(L10n.tr("siri_promo.footnote", appConfig.language))
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.spacing24)
    }

    private func dismissAndMarkSeen() {
        appConfig.markSiriPromoSeen()
        dismiss()
    }
}

#Preview("English") {
    SiriPromoModal()
        .environment(AppConfigViewModel())
}

#Preview("Vietnamese Dark") {
    let vm = AppConfigViewModel()
    vm.setLanguage("vi")
    return SiriPromoModal()
        .environment(vm)
        .preferredColorScheme(.dark)
}

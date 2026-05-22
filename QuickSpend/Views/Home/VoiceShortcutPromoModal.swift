import SwiftUI
import UIKit

/// One-time modal that introduces the Siri/Shortcuts voice expense flow and
/// deep-links the user into Shortcuts.app to install the pre-built shortcut.
/// Fires once per install regardless of upgrade vs fresh path — the feature
/// lives outside the app and onboarding doesn't cover it.
struct VoiceShortcutPromoModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var heroAppeared = false
    @State private var contentAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacing32) {
                    Spacer(minLength: AppTheme.spacing32)

                    hero

                    titleBlock
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    benefits
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                    siriTip
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                    Spacer(minLength: AppTheme.spacing16)
                }
            }

            cta
                .opacity(contentAppeared ? 1 : 0)
        }
        .interactiveDismissDisabled()
        .onAppear(perform: runEntranceAnimation)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            RadialGradient(
                colors: [
                    AppTheme.primaryGreen.opacity(colorScheme == .dark ? 0.35 : 0.22),
                    AppTheme.primaryLight.opacity(0.0),
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .frame(height: 220)
            .blur(radius: 28)

            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 140, height: 140)
                    .shadow(
                        color: AppTheme.primaryGreen.opacity(colorScheme == .dark ? 0.35 : 0.25),
                        radius: 22,
                        y: 8
                    )

                Image(systemName: "mic.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)

                // Subtle Siri-style ring
                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 168, height: 168)
            }
        }
        .scaleEffect(heroAppeared ? 1.0 : 0.85)
        .opacity(heroAppeared ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("voice_shortcut.promo_title", appConfig.language))
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Text(L10n.tr("voice_shortcut.promo_title", appConfig.language))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(L10n.tr("voice_shortcut.promo_subtitle", appConfig.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacing16)
        }
    }

    // MARK: - Benefits

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
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(L10n.tr(key, appConfig.language))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Siri Tip

    private var siriTip: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: "waveform")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("voice_shortcut.siri_tip_title", appConfig.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(L10n.tr("voice_shortcut.siri_tip_body", appConfig.language))
                    .font(.caption)
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

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: AppTheme.spacing8) {
            Button {
                installShortcut()
            } label: {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.headline)
                    Text(L10n.tr("voice_shortcut.install_cta", appConfig.language))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.adaptiveAccent(colorScheme))

            Button {
                dismissAndMarkSeen()
            } label: {
                Text(L10n.tr("voice_shortcut.later_cta", appConfig.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing8)
            }
        }
        .padding(.horizontal, AppTheme.spacing24)
        .padding(.bottom, AppTheme.spacing16)
    }

    // MARK: - Animation

    private func runEntranceAnimation() {
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.2)) {
                heroAppeared = true
                contentAppeared = true
            }
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            heroAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.18)) {
            contentAppeared = true
        }
    }

    // MARK: - Actions

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

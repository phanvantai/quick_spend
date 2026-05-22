import SwiftUI

/// One-time modal that teaches the user how to trigger expense logging via
/// "Hey Siri, …" phrases — no setup required, works out of the box from any
/// QuickSpend install. Sits between the Balance modal and the Voice Shortcut
/// promo in the post-launch sequence: Siri is the universal fallback,
/// Shortcuts is the one-tap optimisation on top.
struct SiriPromoModal: View {
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

                    phrasesBlock
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                    footnote
                        .opacity(contentAppeared ? 1 : 0)

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
                    Color.purple.opacity(colorScheme == .dark ? 0.30 : 0.20),
                    Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.15),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .frame(height: 220)
            .blur(radius: 28)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(
                        color: Color.purple.opacity(colorScheme == .dark ? 0.35 : 0.25),
                        radius: 22,
                        y: 8
                    )

                Image(systemName: "waveform")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)

                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 168, height: 168)
            }
        }
        .scaleEffect(heroAppeared ? 1.0 : 0.85)
        .opacity(heroAppeared ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("siri_promo.title", appConfig.language))
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Text(L10n.tr("siri_promo.title", appConfig.language))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(L10n.tr("siri_promo.subtitle", appConfig.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacing16)
        }
    }

    // MARK: - Example Phrases

    private var phrasesBlock: some View {
        VStack(spacing: AppTheme.spacing12) {
            phraseCard(key: "siri_promo.example_1", icon: "mic.fill")
            phraseCard(key: "siri_promo.example_2", icon: "sparkles")
        }
        .padding(.horizontal, AppTheme.spacing24)
    }

    private func phraseCard(key: String, icon: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: icon)
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

            Text(L10n.tr(key, appConfig.language))
                .font(.subheadline.weight(.medium))
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

    // MARK: - Footnote

    private var footnote: some View {
        Text(L10n.tr("siri_promo.footnote", appConfig.language))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.spacing24)
    }

    // MARK: - CTA

    private var cta: some View {
        Button {
            dismissAndMarkSeen()
        } label: {
            Text(L10n.tr("siri_promo.got_it_cta", appConfig.language))
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(AppTheme.adaptiveAccent(colorScheme))
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

import SwiftUI

/// Shared shape for QuickSpend's full-screen promo / WhatsNew modals.
///
/// The three v2.x modals (SiriPromo, VoiceShortcutPromo, WhatsNewBalance)
/// duplicated the same ScrollView + staggered entrance + pinned CTA layout
/// with only the hero and middle content varying. ModalTemplate factors that
/// common chrome out so the modals themselves just describe their content.
///
/// Layout (top to bottom):
/// - Scrollable column: spacer, `hero`, title + subtitle, `content`
/// - Pinned CTA block: primary button, optional secondary button
///
/// Entrance animation: spring scale-in for the hero, easeOut slide-in for the
/// title and content; collapses to a quick fade under Reduce Motion. The
/// modal is `.interactiveDismissDisabled()` so the user must use the CTA.
struct ModalTemplate<Hero: View, Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let primary: ModalCTA
    let secondary: ModalCTA?
    @ViewBuilder let hero: () -> Hero
    @ViewBuilder let content: () -> Content

    @State private var heroAppeared = false
    @State private var contentAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacing32) {
                    Spacer(minLength: AppTheme.spacing32)

                    hero()
                        .scaleEffect(heroAppeared ? 1.0 : 0.9)
                        .opacity(heroAppeared ? 1 : 0)

                    titleBlock
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    content()
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                    Spacer(minLength: AppTheme.spacing16)
                }
            }

            ctaBlock
                .opacity(contentAppeared ? 1 : 0)
        }
        .interactiveDismissDisabled()
        .onAppear(perform: runEntrance)
    }

    private var titleBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacing16)
        }
    }

    private var ctaBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Button(action: primary.action) {
                primaryLabel
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.adaptiveAccent(colorScheme))

            if let secondary {
                Button(action: secondary.action) {
                    Text(secondary.label)
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacing8)
                }
            }
        }
        .padding(.horizontal, AppTheme.spacing24)
        .padding(.bottom, AppTheme.spacing16)
    }

    @ViewBuilder
    private var primaryLabel: some View {
        if let icon = primary.icon {
            HStack(spacing: AppTheme.spacing8) {
                Image(systemName: icon)
                    .font(Typography.headline)
                Text(primary.label)
                    .font(Typography.headline)
            }
        } else {
            Text(primary.label)
                .font(Typography.headline)
        }
    }

    private func runEntrance() {
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.2)) {
                heroAppeared = true
                contentAppeared = true
            }
            return
        }
        withAnimation(.springSmooth) {
            heroAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.18)) {
            contentAppeared = true
        }
    }
}

/// A primary or secondary call-to-action button used inside `ModalTemplate`.
/// The primary button is always rendered as borderedProminent; the secondary,
/// when present, renders as a quieter text button beneath it.
struct ModalCTA {
    let label: String
    let icon: String?
    let action: () -> Void

    init(label: String, icon: String? = nil, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.action = action
    }
}

/// Reusable hero for promo modals: radial glow + gradient circle + center
/// SF Symbol + outer ring. Configurable colors and icon. Used by SiriPromo
/// and VoiceShortcutPromo; modals with non-symbol heroes (like
/// WhatsNewBalance, which previews the actual BalanceHero) supply their own.
struct ModalGradientHero: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let gradient: LinearGradient
    let glowColor: Color
    /// When true, the SF Symbol uses `.variableColor.iterative.reversing` so
    /// it pulses — fitting for waveform / sound visuals.
    let animatedSymbol: Bool

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    glowColor.opacity(colorScheme == .dark ? 0.35 : 0.22),
                    glowColor.opacity(0.0),
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .frame(height: 220)
            .blur(radius: 28)

            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 140, height: 140)
                    .shadow(
                        color: glowColor.opacity(colorScheme == .dark ? 0.35 : 0.25),
                        radius: 22,
                        y: 8
                    )

                symbol

                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 168, height: 168)
            }
        }
    }

    @ViewBuilder
    private var symbol: some View {
        let base = Image(systemName: icon)
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.white)

        if animatedSymbol {
            base.symbolEffect(.variableColor.iterative.reversing, options: .repeating)
        } else {
            base
        }
    }
}

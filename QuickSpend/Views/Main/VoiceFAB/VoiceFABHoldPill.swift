import SwiftUI

/// Style D — Pill (idle) with mic icon + tiny "Hold" label. Morphs into
/// a circle with reactive audio bars when recording starts.
struct VoiceFABHoldPill: View {
    let ctx: VoiceFABVisualContext
    let language: String

    @State private var ripple: CGFloat = 0
    @State private var breathe = false

    private let pillWidth: CGFloat = 140
    private let pillHeight: CGFloat = 56
    private let circleSize: CGFloat = 72

    var body: some View {
        ZStack {
            if ctx.isRecording {
                rippleRings
                waveformBars
            }

            shape
                .overlay(content)
                .shadow(color: ctx.activeColor.opacity(0.4), radius: 14, y: 8)
        }
        .scaleEffect(ctx.isPressed ? 0.94 : (breathe && !ctx.isRecording ? 1.015 : 1.0))
        .animation(.springSmooth, value: ctx.isRecording)
        .animation(.springFast, value: ctx.isPressed)
        .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .onChange(of: ctx.isRecording) { _, recording in
            if recording {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    ripple = 1
                }
            } else {
                ripple = 0
            }
        }
    }

    // MARK: - Shape (pill ↔ circle morph)

    @ViewBuilder
    private var shape: some View {
        if ctx.isRecording {
            Circle()
                .fill(ctx.activeColor)
                .frame(width: circleSize, height: circleSize)
        } else {
            Capsule()
                .fill(AppTheme.primaryGradient)
                .frame(width: pillWidth, height: pillHeight)
        }
    }

    // MARK: - Content (label idle, icon recording)

    @ViewBuilder
    private var content: some View {
        if ctx.isRecording {
            Image(systemName: ctx.isDragCancelling ? "xmark" : "mic.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: ctx.isRecording)
        } else {
            HStack(spacing: AppTheme.spacing8) {
                Image(systemName: "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(L10n.tr("voice.hold_label", language))
                    .font(Typography.captionEmphasized)
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(1.0)
            }
            .padding(.horizontal, AppTheme.spacing16)
        }
    }

    // MARK: - Ripple rings (recording)

    private var rippleRings: some View {
        ForEach(0..<3, id: \.self) { i in
            let delay = CGFloat(i) * 0.33
            let phase = (ripple + 1 - delay).truncatingRemainder(dividingBy: 1)
            Circle()
                .stroke(ctx.activeColor.opacity(Double(1 - phase) * 0.5), lineWidth: 2)
                .frame(width: circleSize + phase * 70, height: circleSize + phase * 70)
        }
    }

    // MARK: - Waveform bars (recording)

    private var waveformBars: some View {
        let level = CGFloat(min(max(ctx.soundLevel, 0), 1))
        return ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 360
                let baseHeight: CGFloat = 8
                let dynamic = baseHeight + level * 14
                Capsule()
                    .fill(ctx.activeColor)
                    .frame(width: 3, height: dynamic)
                    .offset(y: -52)
                    .rotationEffect(.degrees(angle))
                    .animation(.easeOut(duration: 0.12), value: ctx.soundLevel)
            }
        }
    }
}

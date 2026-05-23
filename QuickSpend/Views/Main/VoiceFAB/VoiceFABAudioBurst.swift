import SwiftUI

/// Style A — Clean gradient circle. Idle: very subtle breathing.
/// Recording: 3 concentric ripple rings + 8 reactive waveform bars
/// arranged around the rim. Drag-cancel turns red.
struct VoiceFABAudioBurst: View {
    let ctx: VoiceFABVisualContext

    @State private var breathe = false
    /// Ripple phase 0…1; loops while recording.
    @State private var ripple: CGFloat = 0

    var body: some View {
        ZStack {
            if ctx.isRecording {
                rippleRings
                waveformBars
            }
            mainCircle
            iconContent
        }
        .scaleEffect(ctx.isPressed ? 0.92 : (breathe && !ctx.isRecording ? 1.02 : 1.0))
        .animation(.springFast, value: ctx.isPressed)
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathe)
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

    // MARK: - Main circle

    private var mainCircle: some View {
        Circle()
            .fill(mainFill)
            .frame(width: 68, height: 68)
            .shadow(color: ctx.activeColor.opacity(0.4), radius: 14, y: 8)
    }

    private var mainFill: some ShapeStyle {
        if ctx.isRecording {
            return AnyShapeStyle(
                RadialGradient(
                    colors: [ctx.activeColor, ctx.activeColor.opacity(0.85)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 40
                )
            )
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
    }

    // MARK: - Ripple rings (3 concentric, staggered)

    private var rippleRings: some View {
        ForEach(0..<3, id: \.self) { i in
            let delay = CGFloat(i) * 0.33
            let phase = (ripple + 1 - delay).truncatingRemainder(dividingBy: 1)
            Circle()
                .stroke(ctx.activeColor.opacity(Double(1 - phase) * 0.5), lineWidth: 2)
                .frame(width: 68 + phase * 70, height: 68 + phase * 70)
        }
    }

    // MARK: - Waveform bars around the rim

    private var waveformBars: some View {
        let level = CGFloat(min(max(ctx.soundLevel, 0), 1))
        return ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 360
                let baseHeight: CGFloat = 8
                let dynamic = baseHeight + level * 14 + CGFloat.random(in: 0...4)
                Capsule()
                    .fill(ctx.activeColor)
                    .frame(width: 3, height: dynamic)
                    .offset(y: -50)
                    .rotationEffect(.degrees(angle))
                    .animation(.easeOut(duration: 0.12), value: ctx.soundLevel)
            }
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconContent: some View {
        if ctx.isDragCancelling {
            Image(systemName: "xmark")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
        } else {
            Image(systemName: "mic.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: ctx.isRecording)
        }
    }
}

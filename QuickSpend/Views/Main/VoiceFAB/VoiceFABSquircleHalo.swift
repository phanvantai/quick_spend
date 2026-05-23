import SwiftUI

/// Style B — Squircle (continuous corner radius, ~iOS app icon shape)
/// with a soft radial halo behind it. Halo breathes idly and grows with
/// soundLevel while recording.
struct VoiceFABSquircleHalo: View {
    let ctx: VoiceFABVisualContext

    @State private var breathe = false

    private let squircleSize: CGFloat = 64
    /// Continuous-corner squircle radius — visually softer than the
    /// default rounded rectangle at the same numeric value.
    private let cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            halo
            squircle
            iconContent
        }
        .scaleEffect(ctx.isPressed ? 0.94 : 1.0)
        .animation(.springFast, value: ctx.isPressed)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: - Halo

    private var halo: some View {
        let level = CGFloat(min(max(ctx.soundLevel, 0), 1))
        let baseScale: CGFloat = breathe ? 1.05 : 0.95
        let recordingBoost = ctx.isRecording ? 0.4 + level * 0.6 : 0
        let scale = baseScale + recordingBoost

        return RadialGradient(
            colors: [
                ctx.activeColor.opacity(ctx.isRecording ? 0.55 : 0.28),
                ctx.activeColor.opacity(0)
            ],
            center: .center,
            startRadius: 8,
            endRadius: 70
        )
        .frame(width: 140, height: 140)
        .scaleEffect(scale)
        .blur(radius: 6)
        .animation(.easeOut(duration: 0.18), value: ctx.soundLevel)
        .animation(.springSmooth, value: ctx.isRecording)
    }

    // MARK: - Squircle body

    private var squircle: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(squircleFill)
            .frame(width: squircleSize, height: squircleSize)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: ctx.activeColor.opacity(0.45), radius: 18, y: 10)
    }

    private var squircleFill: some ShapeStyle {
        if ctx.isRecording {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [ctx.activeColor, ctx.activeColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
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
                .symbolEffect(.variableColor.iterative.reversing, options: ctx.isRecording ? .repeating : .nonRepeating)
        }
    }
}

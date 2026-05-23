import SwiftUI

/// Style C — Circle with a conic-gradient sweep around the rim.
/// Rotates slowly (8s/rev) when idle, accelerates (2s/rev) when
/// recording. Soft outer halo reacts to soundLevel.
struct VoiceFABListeningOrb: View {
    let ctx: VoiceFABVisualContext

    @State private var rotation: Double = 0

    private let outerSize: CGFloat = 76
    private let innerSize: CGFloat = 60

    var body: some View {
        ZStack {
            outerHalo
            sweepRing
            innerCircle
            iconContent
        }
        .scaleEffect(ctx.isPressed ? 0.93 : 1.0)
        .animation(.springFast, value: ctx.isPressed)
        .onAppear { startRotation(fast: false) }
        .onChange(of: ctx.isRecording) { _, recording in
            startRotation(fast: recording)
        }
    }

    /// Restart the angular animation with the speed for the new mode.
    /// SwiftUI doesn't change the duration of a `repeatForever` mid-run,
    /// so we reset the state then re-apply.
    private func startRotation(fast: Bool) {
        rotation = 0
        let duration = fast ? 2.0 : 8.0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    // MARK: - Halo (reacts to soundLevel while recording)

    private var outerHalo: some View {
        let level = CGFloat(min(max(ctx.soundLevel, 0), 1))
        let scale: CGFloat = ctx.isRecording ? 1.05 + level * 0.45 : 0.9
        let opacity: Double = ctx.isRecording ? 0.45 : 0.18

        return Circle()
            .fill(ctx.activeColor.opacity(opacity))
            .frame(width: 110, height: 110)
            .blur(radius: 22)
            .scaleEffect(scale)
            .animation(.easeOut(duration: 0.18), value: ctx.soundLevel)
            .animation(.springSmooth, value: ctx.isRecording)
    }

    // MARK: - Conic sweep ring

    private var sweepRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        ctx.activeColor.opacity(0),
                        ctx.activeColor,
                        AppTheme.primaryMint,
                        ctx.activeColor.opacity(0)
                    ],
                    center: .center
                ),
                lineWidth: 4
            )
            .frame(width: outerSize, height: outerSize)
            .rotationEffect(.degrees(rotation))
    }

    // MARK: - Inner circle

    private var innerCircle: some View {
        Circle()
            .fill(innerFill)
            .frame(width: innerSize, height: innerSize)
            .shadow(color: ctx.activeColor.opacity(0.35), radius: 10, y: 6)
    }

    private var innerFill: some ShapeStyle {
        if ctx.isRecording {
            return AnyShapeStyle(ctx.activeColor)
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconContent: some View {
        if ctx.isDragCancelling {
            Image(systemName: "xmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        } else {
            Image(systemName: "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

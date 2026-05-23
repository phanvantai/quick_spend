import SwiftUI

/// The Voice FAB visual: a circle with a conic-gradient sweep around the
/// rim that rotates continuously. 8s/rev when idle, 2s/rev when recording.
///
/// Rotation is driven by `TimelineView(.animation)` rather than a
/// `repeatForever` animation on a `@State` value. The reason: when the
/// recording flag flips, we don't want the sweep to snap back to 0° and
/// restart — we want the same angle to keep going at the new speed.
///
/// To get speed changes without discontinuity we remember (phase,
/// timestamp) every time the speed changes. The angle at any frame is
/// then `phase + elapsedSinceChange * currentSpeed`. When the speed
/// changes again we freeze the phase using the OUTGOING speed so the
/// curve is C0 continuous.
struct VoiceFABListeningOrb: View {
    let ctx: VoiceFABVisualContext

    /// Cumulative angle at the most recent speed change (in degrees, 0…360).
    @State private var phaseAtChange: Double = 0
    /// Wall-clock moment the current speed regime started.
    @State private var changedAt: Date = .now

    private let outerSize: CGFloat = 76
    private let innerSize: CGFloat = 60

    /// Angular speed in deg/sec for each regime.
    private func speed(recording: Bool) -> Double {
        recording ? 180 : 45  // 360/2s vs 360/8s
    }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(changedAt)
            let angle = (phaseAtChange + elapsed * speed(recording: ctx.isRecording))
                .truncatingRemainder(dividingBy: 360)

            ZStack {
                outerHalo
                sweepRing(angle: angle)
                innerCircle
                iconContent
            }
        }
        .scaleEffect(ctx.isPressed ? 0.93 : 1.0)
        .animation(.springFast, value: ctx.isPressed)
        .onChange(of: ctx.isRecording) { oldValue, _ in
            // Freeze the visible angle using the OUTGOING speed so the
            // sweep keeps going from exactly where it was, just at the
            // new tempo. Without this we'd see a jump every time.
            let elapsed = Date().timeIntervalSince(changedAt)
            let frozen = (phaseAtChange + elapsed * speed(recording: oldValue))
                .truncatingRemainder(dividingBy: 360)
            phaseAtChange = frozen
            changedAt = Date()
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

    private func sweepRing(angle: Double) -> some View {
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
            .rotationEffect(.degrees(angle))
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

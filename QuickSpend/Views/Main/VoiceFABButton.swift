import SwiftUI

/// Floating circular microphone button with hold-to-record interaction.
/// Press and hold to start recording, release to stop and process,
/// drag away to cancel.
struct VoiceFABButton: View {
    let language: String
    let isRecording: Bool
    let soundLevel: Float
    let transcription: String
    let showTutorial: Bool
    let onRecordStart: () -> Void
    let onRecordEnd: () -> Void
    let onRecordCancel: () -> Void
    let onTutorialDismissed: () -> Void
    var onDragCancelStateChange: ((Bool) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPulsing = false
    @State private var isPressed = false
    @State private var isDragCancelling = false
    @State private var dragOffset: CGSize = .zero
    @State private var tutorialVisible = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Tutorial tooltip (shown once for new users)
            if tutorialVisible && !isRecording {
                tutorialTooltip
                    .offset(x: -20, y: -100)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .onTapGesture { dismissTutorial() }
            }

            // FAB button
            fabContent
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .gesture(holdGesture)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                    // Show tutorial after a short delay
                    if showTutorial {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                tutorialVisible = true
                            }
                        }
                        // Auto-dismiss after 6 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                            dismissTutorial()
                        }
                    }
                }
                .accessibilityLabel(L10n.tr("voice.input", language))
                .accessibilityHint(L10n.tr("voice.hint", language))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: isDragCancelling)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tutorialVisible)
    }

    private func dismissTutorial() {
        guard tutorialVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            tutorialVisible = false
        }
        onTutorialDismissed()
    }

    // MARK: - FAB Content

    private var fabContent: some View {
        ZStack {
            pulseRings
            mainCircle
            iconContent
        }
    }

    // MARK: - Pulse Rings

    @ViewBuilder
    private var pulseRings: some View {
        if isRecording {
            Circle()
                .fill(buttonAccentColor.opacity(0.12))
                .frame(width: 100, height: 100)
                .scaleEffect(1.0 + CGFloat(soundLevel) * 0.5)
                .animation(.easeOut(duration: 0.1), value: soundLevel)

            Circle()
                .fill(buttonAccentColor.opacity(0.25))
                .frame(width: 84, height: 84)
                .scaleEffect(1.0 + CGFloat(soundLevel) * 0.3)
                .animation(.easeOut(duration: 0.1), value: soundLevel)
        } else {
            Circle()
                .fill(AppTheme.primaryMint.opacity(0.08))
                .frame(width: 88, height: 88)
                .scaleEffect(isPulsing ? 1.08 : 1.0)

            Circle()
                .stroke(AppTheme.primaryMint.opacity(0.2), lineWidth: 1.5)
                .frame(width: 80, height: 80)
        }
    }

    // MARK: - Main Circle

    private var mainCircle: some View {
        Circle()
            .fill(mainCircleFill)
            .frame(width: 68, height: 68)
            .shadow(
                color: mainCircleShadowColor,
                radius: 12,
                x: 0,
                y: 6
            )
    }

    private var mainCircleFill: some ShapeStyle {
        if isRecording {
            return AnyShapeStyle(isDragCancelling ? AppTheme.error : buttonAccentColor)
        }
        return AnyShapeStyle(AppTheme.primaryGradient)
    }

    private var mainCircleShadowColor: Color {
        (isDragCancelling ? AppTheme.error : AppTheme.primaryMint).opacity(0.35)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconContent: some View {
        if isRecording {
            Image(systemName: isDragCancelling ? "xmark" : "mic.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
        } else {
            idleMicIcon
        }
    }

    private var idleMicIcon: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.5))
                .frame(width: 2.5, height: isPulsing ? 18 : 12)

            Image(systemName: "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.5))
                .frame(width: 2.5, height: isPulsing ? 12 : 18)
        }
    }

    // MARK: - Tutorial Tooltip

    private var tutorialTooltip: some View {
        HStack(spacing: AppTheme.spacing8) {
            Image(systemName: "hand.tap.fill")
                .font(.title3)
                .foregroundStyle(buttonAccentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("voice.tutorial_title", language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(L10n.tr("voice.tutorial_subtitle", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .frame(maxWidth: 240, alignment: .trailing)
    }

    // MARK: - Hold Gesture

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed {
                    isPressed = true
                    // Dismiss tutorial on first use
                    if tutorialVisible { dismissTutorial() }
                    onRecordStart()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                dragOffset = value.translation
                let distance = Self.dragDistance(dragOffset)
                let wasCancelling = isDragCancelling
                isDragCancelling = distance > AppConstants.dragCancelThreshold
                if isDragCancelling != wasCancelling {
                    onDragCancelStateChange?(isDragCancelling)
                    if isDragCancelling {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .onEnded { _ in
                isPressed = false
                if isDragCancelling {
                    onRecordCancel()
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    onRecordEnd()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                dragOffset = .zero
                isDragCancelling = false
                onDragCancelStateChange?(false)
            }
    }

    // MARK: - Helpers

    private var buttonAccentColor: Color {
        AppTheme.adaptiveAccent(colorScheme)
    }

    /// Calculate whether a drag translation exceeds the cancel threshold
    static func shouldCancel(translation: CGSize, threshold: CGFloat) -> Bool {
        dragDistance(translation) > threshold
    }

    private static func dragDistance(_ translation: CGSize) -> CGFloat {
        sqrt(pow(translation.width, 2) + pow(translation.height, 2))
    }
}

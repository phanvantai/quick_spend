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
    @State private var isPressed = false
    @State private var isDragCancelling = false
    @State private var dragOffset: CGSize = .zero
    @State private var tutorialVisible = false

    private var visualContext: VoiceFABVisualContext {
        VoiceFABVisualContext(
            isRecording: isRecording,
            isDragCancelling: isDragCancelling,
            isPressed: isPressed,
            soundLevel: soundLevel,
            accent: AppTheme.adaptiveAccent(colorScheme)
        )
    }

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

            // FAB button — visual variant chosen by `style`.
            fabContent
                .gesture(holdGesture)
                .onAppear {
                    if showTutorial {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.springSmooth) {
                                tutorialVisible = true
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                            dismissTutorial()
                        }
                    }
                }
                .accessibilityLabel(L10n.tr("voice.input", language))
                .accessibilityHint(L10n.tr("voice.hint", language))
        }
        .animation(.springFast, value: isRecording)
        .animation(.easeQuick, value: isDragCancelling)
        .animation(.springSmooth, value: tutorialVisible)
    }

    private var fabContent: some View {
        VoiceFABListeningOrb(ctx: visualContext)
    }

    private func dismissTutorial() {
        guard tutorialVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            tutorialVisible = false
        }
        onTutorialDismissed()
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

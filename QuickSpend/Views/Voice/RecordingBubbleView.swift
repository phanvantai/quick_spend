import SwiftUI

/// Full-width recording bubble overlay showing live transcription and sound level bars.
/// Displayed in MainTabView as a sibling overlay during voice recording.
struct RecordingBubbleView: View {
    let language: String
    let transcription: String
    let soundLevel: Float
    let isDragCancelling: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// Max height capped at ~1/3 of screen height
    private var bubbleMaxHeight: CGFloat {
        UIScreen.main.bounds.height / 3
    }

    private var accentColor: Color {
        AppTheme.adaptiveAccent(colorScheme)
    }

    var body: some View {
        VStack(spacing: AppTheme.spacing8) {
            // Cancel indicator
            if isDragCancelling {
                Label(L10n.tr("voice.release_cancel", language), systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.error)
                    .transition(.opacity)
            }

            // Sound level bars
            soundLevelBars

            // Transcription content
            ScrollView(.vertical, showsIndicators: false) {
                if transcription.isEmpty {
                    HStack(spacing: AppTheme.spacing8) {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        Text(L10n.tr("voice.listening", language))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing12)
                } else {
                    Text(transcription)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: bubbleMaxHeight - 80)
        }
        .padding(.horizontal, AppTheme.spacing20)
        .padding(.vertical, AppTheme.spacing16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(
                    isDragCancelling
                        ? AppTheme.error.opacity(0.3)
                        : AppTheme.primaryMint.opacity(0.3)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(
                    isDragCancelling
                        ? AppTheme.error.opacity(0.5)
                        : AppTheme.primaryLight.opacity(0.25 + Double(soundLevel) * 0.3),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (isDragCancelling ? AppTheme.error : accentColor)
                .opacity(0.2 + Double(soundLevel) * 0.15),
            radius: 12 + CGFloat(soundLevel) * 6,
            y: 4
        )
        .animation(.easeOut(duration: 0.1), value: soundLevel)
        .animation(.easeInOut(duration: 0.15), value: isDragCancelling)
    }

    // MARK: - Sound Level Bars

    private var soundLevelBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isDragCancelling
                            ? AppTheme.error.opacity(0.7)
                            : accentColor.opacity(0.5 + Double(soundLevel) * 0.5)
                    )
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.easeOut(duration: 0.1), value: soundLevel)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 4
        let maxExtra: CGFloat = 12
        let phase = Float(index) * 0.15
        let level = min(max(soundLevel + phase * 0.3 - 0.15, 0), 1)
        return base + CGFloat(level) * maxExtra
    }
}

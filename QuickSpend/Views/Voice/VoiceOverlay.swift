import SwiftUI

/// Full-screen voice recording overlay with animated mic and transcription
struct VoiceOverlay: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    let voiceService: VoiceService
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var isCancelling: Bool {
        dragOffset < -100
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { /* block taps */ }

            VStack(spacing: AppTheme.spacing24) {
                Spacer()

                // Status label
                if voiceService.transcription.isEmpty {
                    Text(L10n.tr("voice.listening", appConfig.language))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Transcription
                if !voiceService.transcription.isEmpty {
                    Text(voiceService.transcription)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.spacing32)
                        .transition(.opacity)
                }

                Spacer()

                // Cancel hint (on drag)
                if isCancelling {
                    Text(L10n.tr("voice.release_cancel", appConfig.language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.error)
                        .transition(.opacity)
                }

                // Mic button
                micButton
                    .offset(y: min(dragOffset, 0))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.height
                            }
                            .onEnded { _ in
                                if isCancelling {
                                    onCancel()
                                }
                                dragOffset = 0
                            }
                    )

                // Action buttons
                HStack(spacing: AppTheme.spacing48) {
                    Button {
                        onCancel()
                    } label: {
                        Text(L10n.tr("common.cancel", appConfig.language))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, AppTheme.spacing24)
                            .padding(.vertical, AppTheme.spacing12)
                    }

                    Button {
                        let text = voiceService.stopListening()
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onComplete(text)
                        } else {
                            onCancel()
                        }
                    } label: {
                        Text(L10n.tr("common.done", appConfig.language))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppTheme.spacing24)
                            .padding(.vertical, AppTheme.spacing12)
                            .background {
                                Capsule()
                                    .fill(AppTheme.primaryMint)
                            }
                    }
                }
                .padding(.top, AppTheme.spacing8)

                Spacer()
                    .frame(height: AppTheme.spacing32)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: voiceService.transcription)
        .animation(.easeInOut(duration: 0.15), value: isCancelling)
    }

    // MARK: - Mic Button

    private var micButton: some View {
        ZStack {
            // Pulse ring
            Circle()
                .fill(AppTheme.primaryMint.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(1.0 + CGFloat(voiceService.soundLevel) * 0.5)
                .animation(.easeOut(duration: 0.1), value: voiceService.soundLevel)

            Circle()
                .fill(AppTheme.primaryMint.opacity(0.3))
                .frame(width: 90, height: 90)
                .scaleEffect(1.0 + CGFloat(voiceService.soundLevel) * 0.3)
                .animation(.easeOut(duration: 0.1), value: voiceService.soundLevel)

            // Main button
            Circle()
                .fill(isCancelling ? AppTheme.error : AppTheme.primaryMint)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: isCancelling ? "xmark" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
        }
    }
}

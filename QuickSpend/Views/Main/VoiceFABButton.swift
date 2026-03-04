import SwiftUI

/// Floating circular microphone button anchored to the bottom-trailing corner
struct VoiceFABButton: View {
    let language: String
    let action: () -> Void

    @State private var isPulsing = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring — subtle pulse animation
                Circle()
                    .fill(AppTheme.primaryMint.opacity(0.08))
                    .frame(width: 88, height: 88)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)

                // Inner glow ring
                Circle()
                    .stroke(AppTheme.primaryMint.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 80, height: 80)

                // Main button circle
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 68, height: 68)
                    .shadow(
                        color: AppTheme.primaryMint.opacity(0.35),
                        radius: 12,
                        x: 0,
                        y: 6
                    )

                // Mic icon with waveform bars
                HStack(spacing: 4) {
                    // Left waveform bar
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.5))
                        .frame(width: 2.5, height: isPulsing ? 18 : 12)

                    Image(systemName: "mic.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    // Right waveform bar
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.5))
                        .frame(width: 2.5, height: isPulsing ? 12 : 18)
                }
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
        .accessibilityLabel(L10n.tr("voice.input", language))
        .accessibilityHint(L10n.tr("voice.hint", language))
    }
}

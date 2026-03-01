import SwiftUI

/// Raised circular microphone button that sits centered above the tab bar
struct VoiceFABButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: AppTheme.primaryMint.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .offset(y: -28)
        .accessibilityLabel("Voice input")
        .accessibilityHint("Double tap to add an expense using your voice")
    }
}

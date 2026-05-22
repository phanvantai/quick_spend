import SwiftUI

/// Aurora-style animated gradient background. Two-tone gradient base + three
/// drifting colored blobs blurred into the page. Adapts saturation for light
/// vs dark mode. Used as the root background on Home and Transactions so the
/// glass `.ultraThinMaterial` cards on top have something interesting behind
/// them.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Drives the blob drift. Toggled on appear; spring-tied so respects
    /// reduced-motion via the system Animation framework.
    @State private var animate = false

    private var baseColors: [Color] {
        if colorScheme == .dark {
            return [Color(hex: "0A1F14"), Color(hex: "0B1B2B"), Color(hex: "1B1438")]
        }
        return [Color(hex: "E8F5EE"), Color(hex: "E0F2F5"), Color(hex: "F0E8F8")]
    }

    private var baseGradient: LinearGradient {
        LinearGradient(colors: baseColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var blobOpacity: Double {
        colorScheme == .dark ? 0.55 : 0.45
    }

    var body: some View {
        ZStack {
            baseGradient

            blob(color: AppTheme.primaryGreen, x: animate ? -120 : -160, y: -200, size: 320)
            blob(color: Color(hex: "5EEAD4"), x: animate ? 140 : 100, y: animate ? 80 : 120, size: 280)
            blob(color: Color(hex: "A78BFA"), x: animate ? -100 : -60, y: animate ? 360 : 320, size: 300)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }

    private func blob(color: Color, x: CGFloat, y: CGFloat, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 80)
            .opacity(blobOpacity)
            .offset(x: x, y: y)
            .allowsHitTesting(false)
    }
}

#Preview("Light") {
    AuroraBackground()
}

#Preview("Dark") {
    AuroraBackground()
        .preferredColorScheme(.dark)
}

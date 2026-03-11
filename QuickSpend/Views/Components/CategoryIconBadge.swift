import SwiftUI

/// Reusable category icon badge with configurable shape, size, and style
struct CategoryIconBadge: View {
    let iconName: String
    let color: Color
    var size: CGFloat = 40
    var iconFont: Font = .body
    var shape: BadgeShape = .roundedRect

    enum BadgeShape {
        case circle
        case roundedRect
    }

    var body: some View {
        Group {
            switch shape {
            case .circle:
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: iconName)
                            .font(iconFont)
                            .foregroundStyle(color)
                    }
            case .roundedRect:
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(color.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: iconName)
                            .font(iconFont)
                            .foregroundStyle(color)
                    }
            }
        }
    }
}

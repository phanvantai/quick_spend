import Foundation

/// Category grouping for UI organization
enum CategoryGroup: String, Codable, CaseIterable {
    // Expense groups
    case dailyLiving
    case personal
    case social
    case financial
    // Income groups
    case earned
    case passive
    case received
    // Shared
    case other

    /// SF Symbol icon name for this group
    var iconName: String {
        switch self {
        case .dailyLiving: return "cup.and.saucer.fill"
        case .personal: return "person.fill"
        case .social: return "person.2.fill"
        case .financial: return "banknote.fill"
        case .earned: return "briefcase.fill"
        case .passive: return "chart.line.uptrend.xyaxis"
        case .received: return "gift.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

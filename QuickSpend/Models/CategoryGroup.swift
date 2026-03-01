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
}

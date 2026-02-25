import Foundation

/// Recurrence pattern for recurring expenses
enum RecurrencePattern: String, Codable, CaseIterable {
    case none
    case monthly
    case yearly

    /// Whether this represents a recurring pattern
    var isRecurring: Bool {
        self != .none
    }
}

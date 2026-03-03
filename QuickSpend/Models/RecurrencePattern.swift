import Foundation

/// Recurrence pattern for recurring transactions
enum RecurrencePattern: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
}

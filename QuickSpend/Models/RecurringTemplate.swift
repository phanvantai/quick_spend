import Foundation
import SwiftData

/// Recurring transaction template configuration
/// Generates normal transactions on schedule
@Model
final class RecurringTemplate {
    var id: String = ""
    var amount: Double = 0
    var note: String = ""
    var categoryId: String = ""
    var type: TransactionType = TransactionType.expense
    var pattern: RecurrencePattern = RecurrencePattern.monthly
    var startDate: Date = Date.now
    var endDate: Date?
    var lastGeneratedDate: Date?
    var isActive: Bool = true
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        amount: Double,
        note: String,
        categoryId: String,
        type: TransactionType = .expense,
        pattern: RecurrencePattern = .monthly,
        startDate: Date = .now,
        endDate: Date? = nil,
        lastGeneratedDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryId = categoryId
        self.type = type
        self.pattern = pattern
        self.startDate = startDate
        self.endDate = endDate
        self.lastGeneratedDate = lastGeneratedDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

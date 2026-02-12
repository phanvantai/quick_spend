import Foundation
import SwiftData

/// Recurring expense template configuration
/// Separate from Expense - generates normal expenses on schedule
@Model
final class RecurringTemplate {
    @Attribute(.unique) var id: String
    var amount: Double
    var descriptionText: String
    var categoryId: String
    var language: String
    var userId: String
    var typeRawValue: String
    var patternRawValue: String
    var startDate: Date
    var endDate: Date?
    var lastGeneratedDate: Date?
    var isActive: Bool

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var pattern: RecurrencePattern {
        get { RecurrencePattern(rawValue: patternRawValue) ?? .none }
        set { patternRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        amount: Double,
        descriptionText: String,
        categoryId: String,
        language: String = "en",
        userId: String = AppConstants.defaultUserId,
        type: TransactionType = .expense,
        pattern: RecurrencePattern = .monthly,
        startDate: Date = .now,
        endDate: Date? = nil,
        lastGeneratedDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.amount = amount
        self.descriptionText = descriptionText
        self.categoryId = categoryId
        self.language = language
        self.userId = userId
        self.typeRawValue = type.rawValue
        self.patternRawValue = pattern.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.lastGeneratedDate = lastGeneratedDate
        self.isActive = isActive
    }
}

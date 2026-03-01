import Foundation
import SwiftData

/// Service for generating expenses from recurring templates
struct RecurringService {

    /// Generate all pending recurring expenses
    /// Should be called on app startup
    @MainActor
    static func generatePendingExpenses(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let templates = try? modelContext.fetch(descriptor) else { return 0 }

        var totalGenerated = 0
        for template in templates {
            totalGenerated += generateExpenses(for: template, modelContext: modelContext)
        }

        if totalGenerated > 0 {
            print("[RecurringService] Generated \(totalGenerated) recurring expense(s)")
        }
        return totalGenerated
    }

    /// Generate expenses for a single template
    @MainActor
    private static func generateExpenses(
        for template: RecurringTemplate,
        modelContext: ModelContext
    ) -> Int {
        guard template.pattern != .none else { return 0 }
        guard template.isActive else { return 0 }

        let now = Date.now
        let calendar = Calendar.current

        // If template has ended, skip
        if let endDate = template.endDate, now > endDate {
            return 0
        }

        // Determine start: next occurrence after lastGeneratedDate, or startDate
        let startDate: Date
        if let lastGenerated = template.lastGeneratedDate {
            startDate = nextOccurrence(after: lastGenerated, pattern: template.pattern, calendar: calendar)
        } else {
            startDate = template.startDate
        }

        let effectiveEnd = template.endDate.map { min($0, now) } ?? now
        let dates = calculateDates(
            from: startDate,
            through: effectiveEnd,
            pattern: template.pattern,
            now: now,
            calendar: calendar
        )

        guard !dates.isEmpty else { return 0 }

        var lastGenerated: Date?
        for date in dates {
            let expense = Expense(
                amount: template.amount,
                descriptionText: template.descriptionText,
                categoryId: template.categoryId,
                language: template.language,
                date: date,
                userId: template.userId,
                rawInput: "Recurring: \(template.descriptionText)",
                confidence: 1.0,
                type: template.type
            )
            modelContext.insert(expense)
            lastGenerated = date
        }

        if let lastGenerated {
            template.lastGeneratedDate = lastGenerated
        }

        return dates.count
    }

    // MARK: - Date Calculation

    private static func calculateDates(
        from startDate: Date,
        through endDate: Date,
        pattern: RecurrencePattern,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var current = startDate

        while current <= endDate && current <= now {
            dates.append(current)
            current = nextOccurrence(after: current, pattern: pattern, calendar: calendar)

            // Safety limit
            if dates.count >= AppConstants.maxRecurringInstancesPerGeneration {
                print("[RecurringService] Hit safety limit of \(AppConstants.maxRecurringInstancesPerGeneration)")
                break
            }
        }

        return dates
    }

    private static func nextOccurrence(
        after date: Date,
        pattern: RecurrencePattern,
        calendar: Calendar
    ) -> Date {
        switch pattern {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .none:
            return date
        }
    }
}

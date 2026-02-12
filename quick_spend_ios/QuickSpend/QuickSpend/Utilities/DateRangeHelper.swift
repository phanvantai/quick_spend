import Foundation

/// Date range calculation utilities
enum DateRangeHelper {
    /// Get start and end of today
    static func today() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
        return (start, end)
    }

    /// Get start and end of this week
    static func thisWeek() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: end)!
        return (start, calendar.date(byAdding: .day, value: 1, to: end)!.addingTimeInterval(-1))
    }

    /// Get start and end of this month
    static func thisMonth() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -29, to: end)!
        return (start, calendar.date(byAdding: .day, value: 1, to: end)!.addingTimeInterval(-1))
    }

    /// Get start and end of this year
    static func thisYear() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -364, to: end)!
        return (start, calendar.date(byAdding: .day, value: 1, to: end)!.addingTimeInterval(-1))
    }

    /// Get start and end of a specific month
    static func month(year: Int, month: Int) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        let start = calendar.date(from: startComponents)!

        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let end = calendar.date(byAdding: endComponents, to: start)!

        return (start, end)
    }
}

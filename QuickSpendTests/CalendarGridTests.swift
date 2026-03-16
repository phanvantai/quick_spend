import Testing
import Foundation
@testable import QuickSpend

@Suite("CalendarGrid offset tests")
struct CalendarGridTests {

    // Helper: build a Date for the 1st of a given year/month in the Gregorian calendar
    private func firstOfMonth(year: Int, month: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: comps)!
    }

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // MARK: - Regression: March 2026

    @Test("March 1 2026 is Sunday → offset 0")
    func march2026StartsOnSunday() {
        // March 1, 2026 is a Sunday (weekday=1 in Gregorian)
        let march2026 = firstOfMonth(year: 2026, month: 3)
        let offset = calendarFirstWeekdayOffset(for: march2026, calendar: utcCalendar())
        #expect(offset == 0)
    }

    @Test("March 16 2026 lands in column 1 (Monday)")
    func march16IsInMondayColumn() {
        let march2026 = firstOfMonth(year: 2026, month: 3)
        let offset = calendarFirstWeekdayOffset(for: march2026, calendar: utcCalendar())
        // Day 16 → grid index = offset + (16 - 1) = 0 + 15 = 15 → column = 15 % 7 = 1 (Monday)
        let column = (offset + 15) % 7
        #expect(column == 1)
    }

    // MARK: - All weekday starts

    @Test("Month starting on Sunday → offset 0")
    func sundayStart() {
        // March 1, 2026 = Sunday
        let date = firstOfMonth(year: 2026, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 0)
    }

    @Test("Month starting on Monday → offset 1")
    func mondayStart() {
        // March 1, 2021 = Monday
        let date = firstOfMonth(year: 2021, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 1)
    }

    @Test("Month starting on Tuesday → offset 2")
    func tuesdayStart() {
        // March 1, 2022 = Tuesday
        let date = firstOfMonth(year: 2022, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 2)
    }

    @Test("Month starting on Wednesday → offset 3")
    func wednesdayStart() {
        // March 1, 2023 = Wednesday
        let date = firstOfMonth(year: 2023, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 3)
    }

    @Test("Month starting on Thursday → offset 4")
    func thursdayStart() {
        // February 1, 2024 = Thursday
        let date = firstOfMonth(year: 2024, month: 2)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 4)
    }

    @Test("Month starting on Friday → offset 5")
    func fridayStart() {
        // March 1, 2024 = Friday
        let date = firstOfMonth(year: 2024, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 5)
    }

    @Test("Month starting on Saturday → offset 6")
    func saturdayStart() {
        // March 1, 2025 = Saturday
        let date = firstOfMonth(year: 2025, month: 3)
        #expect(calendarFirstWeekdayOffset(for: date, calendar: utcCalendar()) == 6)
    }

    // MARK: - Locale independence

    @Test("Offset is the same regardless of locale firstWeekday")
    func localeIndependence() {
        // March 2026 starts on Sunday. A Monday-first calendar (firstWeekday=2) should NOT
        // shift the offset — the function always anchors to Sunday.
        let march2026 = firstOfMonth(year: 2026, month: 3)
        var mondayFirstCal = Calendar(identifier: .gregorian)
        mondayFirstCal.timeZone = TimeZone(identifier: "UTC")!
        mondayFirstCal.firstWeekday = 2 // Monday

        let offset = calendarFirstWeekdayOffset(for: march2026, calendar: mondayFirstCal)
        #expect(offset == 0)
    }
}

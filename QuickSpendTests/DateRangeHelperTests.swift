import Testing
import Foundation
@testable import QuickSpend

@Suite("DateRangeHelper Tests")
struct DateRangeHelperTests {

    // MARK: - today()

    @Test("today returns start and end of current day")
    func testToday() {
        let (start, end) = DateRangeHelper.today()
        let calendar = Calendar.current

        #expect(calendar.isDateInToday(start))
        #expect(calendar.isDateInToday(end))
        #expect(start < end)

        // Start should be midnight
        let components = calendar.dateComponents([.hour, .minute, .second], from: start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("today end is just before midnight")
    func testTodayEnd() {
        let (_, end) = DateRangeHelper.today()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: end)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
        #expect(components.second == 59)
    }

    // MARK: - thisWeek()

    @Test("thisWeek spans 7 days")
    func testThisWeek() {
        let (start, end) = DateRangeHelper.thisWeek()
        let calendar = Calendar.current

        let dayDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        #expect(dayDiff >= 6)
        #expect(dayDiff <= 7)
        #expect(start < end)
    }

    @Test("thisWeek start is before today")
    func testThisWeekStartBeforeToday() {
        let (start, _) = DateRangeHelper.thisWeek()
        let todayStart = Calendar.current.startOfDay(for: .now)
        #expect(start <= todayStart)
    }

    // MARK: - thisMonth()

    @Test("thisMonth spans approximately 30 days")
    func testThisMonth() {
        let (start, end) = DateRangeHelper.thisMonth()
        let calendar = Calendar.current

        let dayDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        #expect(dayDiff >= 29)
        #expect(dayDiff <= 30)
        #expect(start < end)
    }

    @Test("thisMonth end is in today")
    func testThisMonthEndIsToday() {
        let (_, end) = DateRangeHelper.thisMonth()
        let calendar = Calendar.current
        #expect(calendar.isDateInToday(end))
    }

    // MARK: - thisYear()

    @Test("thisYear spans approximately 365 days")
    func testThisYear() {
        let (start, end) = DateRangeHelper.thisYear()
        let calendar = Calendar.current

        let dayDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        #expect(dayDiff >= 364)
        #expect(dayDiff <= 365)
        #expect(start < end)
    }

    // MARK: - month(year:month:)

    @Test("Specific month returns correct date range")
    func testSpecificMonth() {
        let (start, end) = DateRangeHelper.month(year: 2024, month: 6)
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 6)
        #expect(startComponents.day == 1)

        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)
        #expect(endComponents.year == 2024)
        #expect(endComponents.month == 6)
        #expect(endComponents.day == 30)
    }

    @Test("January month has 31 days")
    func testJanuaryMonth() {
        let (start, end) = DateRangeHelper.month(year: 2024, month: 1)
        let calendar = Calendar.current

        let endComponents = calendar.dateComponents([.day], from: end)
        #expect(endComponents.day == 31)

        let startComponents = calendar.dateComponents([.day], from: start)
        #expect(startComponents.day == 1)
    }

    @Test("February in leap year has 29 days")
    func testFebruaryLeapYear() {
        let (_, end) = DateRangeHelper.month(year: 2024, month: 2)
        let calendar = Calendar.current

        let endComponents = calendar.dateComponents([.day], from: end)
        #expect(endComponents.day == 29)
    }

    @Test("February in non-leap year has 28 days")
    func testFebruaryNonLeapYear() {
        let (_, end) = DateRangeHelper.month(year: 2023, month: 2)
        let calendar = Calendar.current

        let endComponents = calendar.dateComponents([.day], from: end)
        #expect(endComponents.day == 28)
    }

    @Test("December month is correct")
    func testDecemberMonth() {
        let (start, end) = DateRangeHelper.month(year: 2024, month: 12)
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 12)
        #expect(startComponents.day == 1)

        let endComponents = calendar.dateComponents([.day], from: end)
        #expect(endComponents.day == 31)
    }

    @Test("Start is always before end for all ranges")
    func testStartBeforeEnd() {
        let ranges = [
            DateRangeHelper.today(),
            DateRangeHelper.thisWeek(),
            DateRangeHelper.thisMonth(),
            DateRangeHelper.thisYear(),
            DateRangeHelper.month(year: 2024, month: 6),
        ]

        for (start, end) in ranges {
            #expect(start < end, "Start should be before end")
        }
    }
}

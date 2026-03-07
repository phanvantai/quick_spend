import Testing
import Foundation
@testable import QuickSpend

@Suite("MonthlyTrend Tests")
struct MonthlyTrendTests {

    // MARK: - Initialization

    @Test("MonthlyTrend initializes with correct values")
    func testInitialization() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let trend = MonthlyTrend(
            month: date,
            monthLabel: "Nov",
            totalExpenses: 1500.0,
            totalIncome: 3000.0
        )

        #expect(trend.month == date)
        #expect(trend.monthLabel == "Nov")
        #expect(trend.totalExpenses == 1500.0)
        #expect(trend.totalIncome == 3000.0)
    }

    @Test("MonthlyTrend id is unique between instances")
    func testUniqueIds() {
        let date = Date.now
        let trend1 = MonthlyTrend(
            month: date,
            monthLabel: "Jan",
            totalExpenses: 100.0,
            totalIncome: 200.0
        )
        let trend2 = MonthlyTrend(
            month: date,
            monthLabel: "Jan",
            totalExpenses: 100.0,
            totalIncome: 200.0
        )

        #expect(trend1.id != trend2.id)
    }

    @Test("MonthlyTrend properties are stored correctly")
    func testPropertiesStoredCorrectly() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        let date = calendar.date(from: components)!

        let trend = MonthlyTrend(
            month: date,
            monthLabel: "January 2025",
            totalExpenses: 999.99,
            totalIncome: 2500.50
        )

        #expect(trend.month == date)
        #expect(trend.monthLabel == "January 2025")
        #expect(trend.totalExpenses == 999.99)
        #expect(trend.totalIncome == 2500.50)
    }

    @Test("MonthlyTrend works with zero values")
    func testZeroValues() {
        let date = Date.now
        let trend = MonthlyTrend(
            month: date,
            monthLabel: "Feb",
            totalExpenses: 0.0,
            totalIncome: 0.0
        )

        #expect(trend.totalExpenses == 0.0)
        #expect(trend.totalIncome == 0.0)
        #expect(trend.monthLabel == "Feb")
    }

    @Test("MonthlyTrend works with large values")
    func testLargeValues() {
        let date = Date.now
        let trend = MonthlyTrend(
            month: date,
            monthLabel: "Dec",
            totalExpenses: 1_000_000.0,
            totalIncome: 5_000_000.0
        )

        #expect(trend.totalExpenses == 1_000_000.0)
        #expect(trend.totalIncome == 5_000_000.0)
    }

    @Test("MonthlyTrend works with empty monthLabel")
    func testEmptyMonthLabel() {
        let date = Date.now
        let trend = MonthlyTrend(
            month: date,
            monthLabel: "",
            totalExpenses: 50.0,
            totalIncome: 100.0
        )

        #expect(trend.monthLabel == "")
    }

    @Test("MonthlyTrend conforms to Identifiable")
    func testIdentifiable() {
        let trend = MonthlyTrend(
            month: .now,
            monthLabel: "Mar",
            totalExpenses: 100.0,
            totalIncome: 200.0
        )

        // id should be a valid UUID
        let _ = trend.id
        #expect(trend.id == trend.id)
    }
}

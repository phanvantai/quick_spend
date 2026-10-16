import Foundation
import Testing
@testable import QuickSpend

@Suite("ReportPeriod Tests")
struct ReportPeriodTests {

    @Test("Only the current month is free")
    func testPremiumGating() {
        #expect(ReportPeriod.thisMonth.requiresPremium == false)
        #expect(ReportPeriod.lastMonth.requiresPremium == true)
        #expect(ReportPeriod.last3Months.requiresPremium == true)
    }

    @Test("Free users' longest report is this month")
    func testLongestFreePeriod() {
        #expect(ReportPeriod.longestAvailable(isPremium: false) == .thisMonth)
    }

    @Test("Premium users' longest report is the last 3 months")
    func testLongestPremiumPeriod() {
        #expect(ReportPeriod.longestAvailable(isPremium: true) == .last3Months)
    }

    @Test("Paywall report values describe the real limits in every language")
    func testPaywallValuesMatchPeriodLabels() {
        for language in ["en", "vi", "ja", "es"] {
            #expect(ReportPeriod.paywallValue(isPremium: false, language: language)
                == ReportPeriod.thisMonth.label(language: language))
            #expect(ReportPeriod.paywallValue(isPremium: true, language: language)
                == ReportPeriod.last3Months.label(language: language))
        }
        #expect(ReportPeriod.paywallValue(isPremium: false, language: "en") == "This Month")
        #expect(ReportPeriod.paywallValue(isPremium: true, language: "en") == "3 Months")
    }

    @Test("Last 3 months spans the current month and the two before it")
    func testLast3MonthsRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2030, month: 3, day: 15))!

        let range = ReportPeriod.last3Months.dateRange(now: now, calendar: calendar)

        #expect(range.start == calendar.date(from: DateComponents(year: 2030, month: 1, day: 1)))
        #expect(range.end == calendar.date(from: DateComponents(year: 2030, month: 4, day: 1)))
    }
}

import Testing
import Foundation
@testable import QuickSpend

@Suite("HomeStrings Tests")
struct HomeStringsTests {

    // MARK: - Helpers

    /// January 15, 2025 at noon UTC
    private var fixedDate: Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }

    /// July 20, 2025 at noon UTC
    private var julyDate: Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 7
        components.day = 20
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }

    /// December 31, 2025 at noon UTC
    private var decemberDate: Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 31
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }

    // MARK: - monthAbbreviation Vietnamese

    @Test("monthAbbreviation returns T-prefix format for Vietnamese")
    func testMonthAbbreviationVietnamese() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "vi")
        #expect(result == "T1")
    }

    @Test("monthAbbreviation returns correct month number for Vietnamese in July")
    func testMonthAbbreviationVietnameseJuly() {
        let result = HomeStrings.monthAbbreviation(for: julyDate, language: "vi")
        #expect(result == "T7")
    }

    @Test("monthAbbreviation returns T12 for Vietnamese in December")
    func testMonthAbbreviationVietnameseDecember() {
        let result = HomeStrings.monthAbbreviation(for: decemberDate, language: "vi")
        #expect(result == "T12")
    }

    // MARK: - monthAbbreviation Japanese

    @Test("monthAbbreviation returns month-tsuki format for Japanese")
    func testMonthAbbreviationJapanese() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "ja")
        #expect(result == "1月")
    }

    @Test("monthAbbreviation returns correct month for Japanese in July")
    func testMonthAbbreviationJapaneseJuly() {
        let result = HomeStrings.monthAbbreviation(for: julyDate, language: "ja")
        #expect(result == "7月")
    }

    // MARK: - monthAbbreviation English

    @Test("monthAbbreviation returns short month name for English")
    func testMonthAbbreviationEnglish() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "en")
        #expect(result == "Jan")
    }

    @Test("monthAbbreviation returns Jul for English in July")
    func testMonthAbbreviationEnglishJuly() {
        let result = HomeStrings.monthAbbreviation(for: julyDate, language: "en")
        #expect(result == "Jul")
    }

    // MARK: - monthAbbreviation Spanish

    @Test("monthAbbreviation returns non-empty for Spanish")
    func testMonthAbbreviationSpanish() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "es")
        #expect(!result.isEmpty)
    }

    // MARK: - monthAbbreviation with showYear

    @Test("monthAbbreviation with showYear appends year for Vietnamese")
    func testMonthAbbreviationShowYearVietnamese() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "vi", showYear: true)
        #expect(result == "T1/2025")
    }

    @Test("monthAbbreviation with showYear appends year for Japanese")
    func testMonthAbbreviationShowYearJapanese() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "ja", showYear: true)
        #expect(result == "1月/2025")
    }

    @Test("monthAbbreviation with showYear appends year for English")
    func testMonthAbbreviationShowYearEnglish() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "en", showYear: true)
        #expect(result == "Jan/2025")
    }

    @Test("monthAbbreviation without showYear does not include year")
    func testMonthAbbreviationNoShowYear() {
        let result = HomeStrings.monthAbbreviation(for: fixedDate, language: "en", showYear: false)
        #expect(!result.contains("2025"))
    }

    // MARK: - monthLabel Vietnamese

    @Test("monthLabel returns Thang format for Vietnamese")
    func testMonthLabelVietnamese() {
        let result = HomeStrings.monthLabel(for: fixedDate, language: "vi")
        #expect(result == "Tháng 1, 2025")
    }

    @Test("monthLabel returns correct format for Vietnamese in December")
    func testMonthLabelVietnameseDecember() {
        let result = HomeStrings.monthLabel(for: decemberDate, language: "vi")
        #expect(result == "Tháng 12, 2025")
    }

    // MARK: - monthLabel Japanese

    @Test("monthLabel returns year-month format for Japanese")
    func testMonthLabelJapanese() {
        let result = HomeStrings.monthLabel(for: fixedDate, language: "ja")
        #expect(result == "2025年1月")
    }

    @Test("monthLabel returns correct format for Japanese in July")
    func testMonthLabelJapaneseJuly() {
        let result = HomeStrings.monthLabel(for: julyDate, language: "ja")
        #expect(result == "2025年7月")
    }

    // MARK: - monthLabel English

    @Test("monthLabel returns full month name for English")
    func testMonthLabelEnglish() {
        let result = HomeStrings.monthLabel(for: fixedDate, language: "en")
        #expect(result == "January, 2025")
    }

    @Test("monthLabel returns non-empty for English in July")
    func testMonthLabelEnglishJuly() {
        let result = HomeStrings.monthLabel(for: julyDate, language: "en")
        #expect(result == "July, 2025")
    }
}

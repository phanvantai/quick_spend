import Testing
import Foundation
@testable import QuickSpend

/// Covers the auto-save / confirm-card threshold logic on `AddExpenseIntent`.
/// Keeps test fixtures local — the parser/save flow itself is exercised by
/// `AddExpenseFlowTests`.
struct AddExpenseIntentTests {

    @Test("Empty parse list never auto-saves — Siri should fall through to error / manual path")
    func testEmptyListNoAutoSave() {
        #expect(AddExpenseIntent.shouldAutoSave([]) == false)
    }

    @Test("Single transaction at exactly threshold (0.9) auto-saves")
    func testSingleAtThreshold() {
        let parsed = [makeParsed(confidence: AddExpenseIntent.autoSaveConfidenceThreshold)]
        #expect(AddExpenseIntent.shouldAutoSave(parsed) == true)
    }

    @Test("Single transaction above threshold auto-saves")
    func testSingleAboveThreshold() {
        let parsed = [makeParsed(confidence: 0.95)]
        #expect(AddExpenseIntent.shouldAutoSave(parsed) == true)
    }

    @Test("Single transaction below threshold falls through to confirm card")
    func testSingleBelowThreshold() {
        let parsed = [makeParsed(confidence: 0.89)]
        #expect(AddExpenseIntent.shouldAutoSave(parsed) == false)
    }

    @Test("Batch with one low-confidence item drops the whole batch into confirm — protects against ambiguous parses landing silently")
    func testBatchWithOneLowItemNoAutoSave() {
        let parsed = [
            makeParsed(confidence: 0.95),
            makeParsed(confidence: 0.88),
            makeParsed(confidence: 0.99)
        ]
        #expect(AddExpenseIntent.shouldAutoSave(parsed) == false)
    }

    @Test("Batch where every item meets threshold auto-saves")
    func testBatchAllHighAutoSave() {
        let parsed = [
            makeParsed(confidence: 0.9),
            makeParsed(confidence: 0.95),
            makeParsed(confidence: 1.0)
        ]
        #expect(AddExpenseIntent.shouldAutoSave(parsed) == true)
    }

    // MARK: - Fixtures

    private func makeParsed(confidence: Double) -> ParsedTransaction {
        ParsedTransaction(
            amount: 50_000,
            note: "Coffee",
            categoryId: "food",
            type: .expense,
            date: Date(),
            confidence: confidence
        )
    }
}

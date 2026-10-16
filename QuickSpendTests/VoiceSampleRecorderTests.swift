import Foundation
import Testing
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

/// Collects samples instead of uploading them.
@MainActor
final class MockVoiceSampleRecorder: VoiceSampleRecording {
    private(set) var recorded: [VoiceSample] = []

    @discardableResult
    func record(_ sample: VoiceSample) -> Task<Void, Never>? {
        recorded.append(sample)
        return nil
    }
}

/// Stands in for Firestore.
private final class MockVoiceSampleStore: VoiceSampleStore, @unchecked Sendable {
    private(set) var submitted: [[String: Any]] = []

    func submit(fields: [String: Any]) async throws {
        submitted.append(fields)
    }
}

@Suite("VoiceSample Tests")
@MainActor
struct VoiceSampleRecorderTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let capturedAt = Date(timeIntervalSince1970: 1_900_000_000)

    private func parsed(
        amount: Double = 45_000,
        categoryId: String = "food_drink",
        daysFromCapture: Int = 0,
        walletId: String? = "wallet_cash_test",
        toWalletId: String? = nil
    ) -> ParsedTransaction {
        var item = ParsedTransaction(
            amount: amount, note: "Coffee test", categoryId: categoryId, type: .expense,
            date: capturedAt.addingTimeInterval(Double(daysFromCapture) * 86_400),
            confidence: 0.8, rawInput: "coffee test"
        )
        item.walletId = walletId
        item.transferToWalletId = toWalletId
        return item
    }

    private var names: VoiceSample.Names {
        VoiceSample.Names(
            categories: [AppCategory(id: "food_drink", name: "Food test", iconName: "fork.knife", colorHex: "#FF0000", type: .expense)],
            wallets: [
                Wallet(id: "wallet_cash_test", name: "Cash test", iconName: "banknote", colorHex: "#00FF00"),
                Wallet(id: "wallet_bank_test", name: "Bank test", iconName: "building.columns", colorHex: "#0000FF"),
            ]
        )
    }

    private func sample(
        input: String = "coffee 45k test",
        parsed items: [ParsedTransaction],
        saved: [Transaction]? = nil
    ) -> VoiceSample {
        VoiceSample(
            input: input, source: .hold, outcome: .review, action: "saved", edited: true,
            language: "vi", currency: "VND", parsed: items, saved: saved,
            names: names, capturedAt: capturedAt, calendar: calendar
        )
    }

    // MARK: - Shape

    @Test("Fields carry the input, the parse, and context — with no identifiers")
    func testFields() {
        let fields = sample(parsed: [parsed(daysFromCapture: -1)]).fields

        #expect(fields["schema"] as? Int == 2)
        #expect(fields["platform"] as? String == "ios")
        #expect(fields["input"] as? String == "coffee 45k test")
        #expect(fields["source"] as? String == "hold")
        #expect(fields["outcome"] as? String == "review")
        #expect(fields["action"] as? String == "saved")
        #expect(fields["edited"] as? Bool == true)
        #expect(fields["language"] as? String == "vi")
        #expect(fields["currency"] as? String == "VND")
        #expect(fields["model"] as? String == AppConstants.geminiModelName)
        #expect(fields["debug"] as? Bool == true)
        #expect(fields["final"] == nil)
        #expect(fields["expire_at"] as? Date == capturedAt.addingTimeInterval(90 * 86_400))
        for key in fields.keys {
            #expect(!key.contains("user"))
            #expect(!key.contains("device"))
        }

        let item = (fields["parsed"] as? [[String: Any]])?.first
        #expect(item?["amount"] as? Double == 45_000)
        #expect(item?["note"] as? String == "Coffee test")
        #expect(item?["category_id"] as? String == "food_drink")
        #expect(item?["category_name"] as? String == "Food test")
        #expect(item?["type"] as? String == "expense")
        #expect(item?["day_offset"] as? Int == -1)
        #expect(item?["confidence"] as? Double == 0.8)
        #expect(item?["wallet"] as? String == "Cash test")
        #expect(item?["is_transfer"] as? Bool == false)
    }

    @Test("Saved transfer legs keep their wallet names and direction")
    func testSavedTransfer() throws {
        let transfer = parsed(categoryId: Transfer.categoryId, toWalletId: "wallet_bank_test")
        let legs = try VoiceTransactionBuilder.transactions(from: [transfer], defaultWalletId: "wallet_cash_test")
        let built = sample(parsed: [transfer], saved: legs)

        #expect(built.parsed.first?.toWalletName == "Bank test")
        #expect(built.parsed.first?.isTransfer == true)
        let final = try #require(built.final)
        #expect(final.count == 2)
        #expect(final.first { $0.transferLeg == "out" }?.walletName == "Cash test")
        #expect(final.first { $0.transferLeg == "in" }?.walletName == "Bank test")
        #expect(final.allSatisfy { $0.confidence == nil })
    }

    @Test("A very long input is cut to the voice input limit")
    func testInputTruncated() {
        let long = String(repeating: "a", count: AppConstants.maxVoiceInputLength + 50)
        #expect(sample(input: long, parsed: []).input.count == AppConstants.maxVoiceInputLength)
    }

    // MARK: - Recorder

    @Test("The recorder uploads when sharing is on")
    func testRecorderUploads() async {
        let store = MockVoiceSampleStore()
        let recorder = VoiceSampleRecorder(store: store, isEnabled: { true })

        await recorder.record(sample(parsed: [parsed()]))?.value

        #expect(store.submitted.count == 1)
        #expect(store.submitted.first?["input"] as? String == "coffee 45k test")
    }

    @Test("The recorder sends nothing when sharing is off or nothing was said")
    func testRecorderSkips() {
        let store = MockVoiceSampleStore()
        let off = VoiceSampleRecorder(store: store, isEnabled: { false })
        let on = VoiceSampleRecorder(store: store, isEnabled: { true })

        #expect(off.record(sample(parsed: [parsed()])) == nil)
        #expect(on.record(sample(input: "", parsed: [])) == nil)
        #expect(store.submitted.isEmpty)
    }

    @Test("Sharing is on by default and can be turned off")
    func testSharingPreference() {
        let suite = "voice-sample-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesService(defaults: defaults)

        #expect(preferences.shareVoiceSamples)
        preferences.shareVoiceSamples = false
        #expect(!preferences.shareVoiceSamples)
        preferences.clearAll()
        #expect(preferences.shareVoiceSamples)
    }
}

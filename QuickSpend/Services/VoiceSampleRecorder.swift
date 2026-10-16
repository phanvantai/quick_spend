import Foundation

/// One anonymous voice capture, kept to improve the parser and prompt: what
/// was said, what the AI returned, and what the user finally kept.
///
/// No user or device identifier is attached. Dates are stored as a day offset
/// from the capture day, not as calendar dates. Firestore's TTL policy on
/// `expire_at` deletes each sample after `AppConstants.voiceSampleRetentionDays`.
struct VoiceSample {

    struct Item: Equatable {
        var amount: Double
        var note: String
        var categoryId: String
        var categoryName: String?
        var type: TransactionType
        var dayOffset: Int
        var confidence: Double?
        var walletName: String?
        var toWalletName: String?
        var isTransfer: Bool
        /// "out" / "in" for a saved transfer leg.
        var transferLeg: String?
    }

    /// Lets items show names the user recognizes (custom categories, wallets).
    struct Names {
        var categories: [String: String] = [:]
        var wallets: [String: String] = [:]

        init(categories: [Category] = [], wallets: [Wallet] = []) {
            self.categories = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            self.wallets = Dictionary(wallets.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        }
    }

    /// Bumped when the stored shape changes. The Flutter app's records have none.
    static let schemaVersion = 2

    var input: String
    var source: VoiceAnalytics.Source
    var outcome: VoiceAnalytics.Outcome
    /// "auto_saved", "saved", or "discarded"; nil when nothing reached the user.
    var action: String?
    var edited: Bool
    var language: String
    var currency: String
    var parsed: [Item]
    /// What was saved; nil when nothing was saved.
    var final: [Item]?
    var appVersion: String
    var build: String
    var model: String
    var isDebugBuild: Bool
    /// When Firestore deletes this sample.
    var expiresAt: Date

    init(
        input: String,
        source: VoiceAnalytics.Source,
        outcome: VoiceAnalytics.Outcome,
        action: String? = nil,
        edited: Bool = false,
        language: String,
        currency: String,
        parsed: [ParsedTransaction] = [],
        saved: [Transaction]? = nil,
        names: Names = Names(),
        capturedAt: Date = .now,
        calendar: Calendar = .current,
        bundle: Bundle = .main
    ) {
        self.input = String(input.prefix(AppConstants.maxVoiceInputLength))
        self.source = source
        self.outcome = outcome
        self.action = action
        self.edited = edited
        self.language = language
        self.currency = currency
        let captureDay = calendar.startOfDay(for: capturedAt)
        func dayOffset(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: captureDay, to: calendar.startOfDay(for: date)).day ?? 0
        }
        self.parsed = parsed.map { item in
            Item(
                amount: item.amount,
                note: item.note,
                categoryId: item.categoryId,
                categoryName: names.categories[item.categoryId],
                type: item.type,
                dayOffset: dayOffset(item.date),
                confidence: item.confidence,
                walletName: item.walletId.flatMap { names.wallets[$0] },
                toWalletName: item.transferToWalletId.flatMap { names.wallets[$0] },
                isTransfer: item.isTransfer,
                transferLeg: nil
            )
        }
        self.final = saved?.map { transaction in
            Item(
                amount: transaction.amount,
                note: transaction.note,
                categoryId: transaction.categoryId,
                categoryName: names.categories[transaction.categoryId],
                type: transaction.type,
                dayOffset: dayOffset(transaction.date),
                confidence: nil,
                walletName: names.wallets[transaction.walletId],
                toWalletName: nil,
                isTransfer: transaction.isTransfer,
                transferLeg: transaction.transferLeg.map { $0 == .outgoing ? "out" : "in" }
            )
        }
        self.appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        self.model = AppConstants.geminiModelName
        self.expiresAt = capturedAt.addingTimeInterval(Double(AppConstants.voiceSampleRetentionDays) * 86_400)
        #if DEBUG
        self.isDebugBuild = true
        #else
        self.isDebugBuild = false
        #endif
    }

    /// Firestore document fields, without the server timestamp.
    var fields: [String: Any] {
        var fields: [String: Any] = [
            "schema": Self.schemaVersion,
            "platform": "ios",
            "input": input,
            "source": source.rawValue,
            "outcome": outcome.rawValue,
            "edited": edited,
            "language": language,
            "currency": currency,
            "parsed": parsed.map(\.fields),
            "app_version": appVersion,
            "build": build,
            "model": model,
            "debug": isDebugBuild,
            "expire_at": expiresAt,
        ]
        if let action { fields["action"] = action }
        if let final { fields["final"] = final.map(\.fields) }
        return fields
    }
}

extension VoiceSample.Item {
    var fields: [String: Any] {
        var fields: [String: Any] = [
            "amount": amount,
            "note": note,
            "category_id": categoryId,
            "type": type.rawValue,
            "day_offset": dayOffset,
            "is_transfer": isTransfer,
        ]
        if let categoryName { fields["category_name"] = categoryName }
        if let confidence { fields["confidence"] = confidence }
        if let walletName { fields["wallet"] = walletName }
        if let toWalletName { fields["to_wallet"] = toWalletName }
        if let transferLeg { fields["transfer_leg"] = transferLeg }
        return fields
    }
}

// MARK: - Store

/// Abstracts Firestore so tests can inject a mock.
protocol VoiceSampleStore: Sendable {
    func submit(fields: [String: Any]) async throws
}

// MARK: - Recorder

@MainActor
protocol VoiceSampleRecording {
    @discardableResult
    func record(_ sample: VoiceSample) -> Task<Void, Never>?
}

/// Sends samples in the background when the user allows it (Settings → Data).
/// Failures are only logged; voice entry never waits on this.
@MainActor
final class VoiceSampleRecorder: VoiceSampleRecording {
    static let shared = VoiceSampleRecorder()

    private let store: VoiceSampleStore?
    private let isEnabled: () -> Bool

    init(
        store: VoiceSampleStore? = VoiceSampleRecorder.defaultStore(),
        isEnabled: @escaping () -> Bool = { PreferencesService.shared.shareVoiceSamples }
    ) {
        self.store = store
        self.isEnabled = isEnabled
    }

    nonisolated static func defaultStore() -> VoiceSampleStore? {
        #if canImport(FirebaseFirestore)
        FirestoreVoiceSampleStore()
        #else
        nil
        #endif
    }

    @discardableResult
    func record(_ sample: VoiceSample) -> Task<Void, Never>? {
        guard isEnabled(), let store, !sample.input.isEmpty else { return nil }
        let fields = sample.fields
        return Task {
            do {
                try await store.submit(fields: fields)
            } catch {
                print("[VoiceSample] Upload failed: \(error)")
            }
        }
    }
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore

struct FirestoreVoiceSampleStore: VoiceSampleStore {
    func submit(fields: [String: Any]) async throws {
        var data = fields
        data["created_at"] = FieldValue.serverTimestamp()
        try await Firestore.firestore()
            .collection(AppConstants.voiceSamplesCollection)
            .addDocument(data: data)
    }
}
#endif

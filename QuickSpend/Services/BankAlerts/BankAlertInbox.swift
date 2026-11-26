import Foundation

/// A bank alert waiting for the user to save or discard it. Holds only what
/// the transaction will hold: no alert text, account number or balance.
struct PendingBankAlert: Codable, Identifiable, Equatable {
    /// The transaction id it will be saved under (`bankalert:<dedupeKey>`).
    let id: String
    let bankId: String?
    /// Shown in the review list; set for template banks, which aren't in `BankInfo.all`.
    var bankName: String? = nil
    /// The user template that read this alert, if any.
    var templateId: String? = nil
    let type: TransactionType
    let amount: Double
    let date: Date
    let note: String
    let categoryId: String
    let walletId: String
    let receivedAt: Date

    var bank: BankInfo? { BankInfo.with(id: bankId) }
    var displayBankName: String? { bankName ?? bank?.name }
    var signedAmount: Double { type == .income ? amount : -amount }

    func makeTransaction(now: Date = .now) -> Transaction {
        Transaction(
            id: id,
            amount: amount,
            note: note,
            categoryId: categoryId,
            walletId: walletId,
            type: type,
            date: date,
            rawInput: nil,
            confidence: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

extension Notification.Name {
    /// Posted when the review list changes, so Home and Settings can refresh.
    static let bankAlertInboxDidChange = Notification.Name("bankAlertInboxDidChange")
}

/// The "To review" list for bank alerts, kept in UserDefaults on this device.
/// The newest item comes first; the list keeps at most `capacity` items.
final class BankAlertInbox {
    static let shared = BankAlertInbox(defaults: .standard)
    static let capacity = 200

    private let defaults: UserDefaults
    private let key = "bank_alert_inbox"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var items: [PendingBankAlert] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([PendingBankAlert].self, from: data) else { return [] }
        return items
    }

    var count: Int { items.count }

    func add(_ item: PendingBankAlert) {
        var list = items.filter { $0.id != item.id }
        list.insert(item, at: 0)
        save(Array(list.prefix(Self.capacity)))
    }

    func remove(id: String) {
        save(items.filter { $0.id != id })
    }

    func removeAll() {
        save([])
    }

    /// An item for the same money movement: same id, or same signed amount
    /// within `window` seconds (the same alert reached us by another channel).
    func containsMatch(id: String, signedAmount: Double, date: Date, window: TimeInterval) -> Bool {
        items.contains { $0.id == id || ($0.signedAmount == signedAmount && abs($0.date.timeIntervalSince(date)) <= window) }
    }

    private func save(_ items: [PendingBankAlert]) {
        if items.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .bankAlertInboxDidChange, object: nil)
    }
}

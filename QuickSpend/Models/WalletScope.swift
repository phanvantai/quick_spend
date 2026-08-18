import Foundation

enum WalletScope: Hashable, RawRepresentable {
    case all
    case wallet(String)

    static let allRawValue = "all"
    static let walletPrefix = "wallet:"

    init?(rawValue: String) {
        if rawValue == Self.allRawValue {
            self = .all
        } else if rawValue.hasPrefix(Self.walletPrefix) {
            let id = String(rawValue.dropFirst(Self.walletPrefix.count))
            guard !id.isEmpty else { return nil }
            self = .wallet(id)
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .all:
            return Self.allRawValue
        case .wallet(let id):
            return Self.walletPrefix + id
        }
    }

    var walletId: String? {
        switch self {
        case .all: return nil
        case .wallet(let id): return id
        }
    }
}

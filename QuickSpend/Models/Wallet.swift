import Foundation
import SwiftData
import SwiftUI

/// User-created ledger scope for separating money streams.
@Model
final class Wallet {
    static let personalID = "wallet_personal"

    var id: String = ""
    var name: String = ""
    var iconName: String = ""
    var colorHex: String = "#000000"
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var color: Color {
        Color(hex: colorHex)
    }

    func displayName(language: String) -> String {
        id == Self.personalID && name == "Personal" ? L10n.tr("wallets.personal", language) : name
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String,
        colorHex: String,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func personal() -> Wallet {
        Wallet(
            id: personalID,
            name: "Personal",
            iconName: "person.crop.circle.fill",
            colorHex: "#2563EB",
            sortOrder: 0
        )
    }
}

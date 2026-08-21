import SwiftUI
import SwiftData

struct WalletFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var name = ""
    @State private var selectedIcon = "briefcase.fill"
    @State private var selectedColor = "#16A34A"

    private let icons = ["briefcase.fill", "creditcard.fill", "banknote.fill", "cart.fill", "airplane", "house.fill"]
    private let colors = ["#16A34A", "#2563EB", "#DC2626", "#9333EA", "#EA580C", "#0891B2"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.tr("wallets.name_placeholder", appConfig.language), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(L10n.tr("wallets.icon", appConfig.language)) {
                    Picker(L10n.tr("wallets.icon", appConfig.language), selection: $selectedIcon) {
                        ForEach(icons, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(L10n.tr("wallets.color", appConfig.language)) {
                    Picker(L10n.tr("wallets.color", appConfig.language), selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            HStack {
                                Circle().fill(Color(hex: color)).frame(width: 16, height: 16)
                                Text(color)
                            }
                            .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(L10n.tr("wallets.new", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let nextSortOrder = (wallets.map(\.sortOrder).max() ?? 0) + 1
        let wallet = Wallet(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIcon,
            colorHex: selectedColor,
            sortOrder: nextSortOrder
        )
        modelContext.insert(wallet)
        try? modelContext.save()
        appConfig.setSelectedWalletScope(.wallet(wallet.id))
        dismiss()
    }
}

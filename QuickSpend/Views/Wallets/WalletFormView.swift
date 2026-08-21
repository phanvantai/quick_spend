import SwiftUI
import SwiftData

struct WalletFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    private let existingWallet: Wallet?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var customColor: Color

    private var isEditMode: Bool { existingWallet != nil }

    init(existingWallet: Wallet? = nil) {
        self.existingWallet = existingWallet
        let defaultColorHex = CategoryColorPalette.colorHex(for: "freelance")
        let colorHex = existingWallet?.colorHex ?? defaultColorHex
        _name = State(initialValue: existingWallet?.name ?? "")
        _selectedIcon = State(initialValue: existingWallet?.iconName ?? "briefcase.fill")
        _selectedColorHex = State(initialValue: colorHex)
        _customColor = State(initialValue: Color(hex: colorHex))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    previewRow
                }

                Section {
                    TextField(L10n.tr("wallets.name_placeholder", appConfig.language), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(L10n.tr("wallets.icon", appConfig.language)) {
                    iconPicker
                }

                Section(L10n.tr("wallets.color", appConfig.language)) {
                    colorPicker

                    ColorPicker(
                        L10n.tr("category_form.custom_color", appConfig.language),
                        selection: $customColor,
                        supportsOpacity: false
                    )
                    .onChange(of: customColor) {
                        selectedColorHex = customColor.toHex()
                    }
                }
            }
            .navigationTitle(isEditMode ? name : L10n.tr("wallets.new", appConfig.language))
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

    private var previewRow: some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: selectedIcon,
                color: Color(hex: selectedColorHex),
                size: 48,
                iconFont: .title3
            )

            Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L10n.tr("wallets.name_placeholder", appConfig.language)
                : name)
                .font(.headline)
                .foregroundStyle(canSave ? .primary : .tertiary)
        }
    }

    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.spacing8)], spacing: AppTheme.spacing8) {
            ForEach(CategoryFormView.availableIcons, id: \.self) { iconName in
                let isSelected = iconName == selectedIcon
                Button {
                    selectedIcon = iconName
                } label: {
                    Image(systemName: iconName)
                        .font(.body)
                        .frame(width: 44, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .fill(isSelected ? Color(hex: selectedColorHex).opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .stroke(isSelected ? Color(hex: selectedColorHex) : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color(hex: selectedColorHex) : .primary)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.spacing12)], spacing: AppTheme.spacing12) {
            ForEach(CategoryColorPalette.availableColorHexes(), id: \.self) { hex in
                let isSelected = hex == selectedColorHex
                Button {
                    selectedColorHex = hex
                    customColor = Color(hex: hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 44, height: 44)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(isSelected ? Color.primary : .clear, lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingWallet {
            existingWallet.name = trimmedName
            existingWallet.iconName = selectedIcon
            existingWallet.colorHex = selectedColorHex
            existingWallet.updatedAt = .now
            try? modelContext.save()
            dismiss()
            return
        }

        let nextSortOrder = (wallets.map(\.sortOrder).max() ?? 0) + 1
        let wallet = Wallet(
            name: trimmedName,
            iconName: selectedIcon,
            colorHex: selectedColorHex,
            sortOrder: nextSortOrder
        )
        modelContext.insert(wallet)
        try? modelContext.save()
        appConfig.setSelectedWalletScope(.wallet(wallet.id))
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct WalletFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balanceService
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    private let existingWallet: Wallet?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var customColor: Color
    @State private var balanceText: String = ""
    @State private var initialBalance: Double?
    @State private var didLoadBalance = false
    @State private var saveError: String?

    private var isEditMode: Bool { existingWallet != nil }

    static func editableBalance(
        from currentBalance: Double,
        config: AppConfig
    ) -> (text: String, value: Double) {
        let text = config.formatNumber(currentBalance)
        return (text, config.parseAmount(text) ?? currentBalance)
    }

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
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard isEditMode else { return true }
        if balanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return initialBalance == nil
        }
        return parsedBalance != nil
    }

    private var parsedBalance: Double? {
        appConfig.config.parseAmount(balanceText)
    }

    @discardableResult
    static func saveBalanceIfChanged(
        parsedBalance: Double?,
        initialBalance: Double?,
        walletId: String,
        balanceService: BalanceService
    ) throws -> Bool {
        guard let parsedBalance, parsedBalance != initialBalance else {
            return false
        }
        try balanceService.setCurrentBalance(parsedBalance, for: walletId)
        return true
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

                if isEditMode {
                    balanceSection
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
            .onAppear(perform: loadBalanceIfNeeded)
            .alert(
                L10n.tr("balance.edit_error_title", appConfig.language),
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                ),
                presenting: saveError
            ) { _ in
                Button(L10n.tr("common.close", appConfig.language)) {
                    saveError = nil
                }
            } message: { error in
                Text(error)
            }
        }
    }

    private var balanceSection: some View {
        Section {
            HStack(spacing: AppTheme.spacing8) {
                Text(appConfig.config.currencySymbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField(
                    L10n.tr("balance.edit_placeholder", appConfig.language),
                    text: $balanceText
                )
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))
                .onChange(of: balanceText) { _, newValue in
                    let formatted = appConfig.config.formatAmountInput(newValue)
                    if formatted != newValue {
                        balanceText = formatted
                    }
                }
                Button(action: toggleBalanceSign) {
                    Text("\u{00B1}")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(balanceText.hasPrefix("-") ? AppTheme.expenseColor : .secondary)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle().fill(Color(.tertiarySystemFill))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("balance.edit_toggle_sign", appConfig.language))
            }
        } header: {
            Text(L10n.tr("settings.balance", appConfig.language))
        } footer: {
            Text(L10n.tr(
                initialBalance == nil ? "balance.edit_hint_new" : "balance.edit_hint_existing",
                appConfig.language
            ))
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

    private func loadBalanceIfNeeded() {
        guard !didLoadBalance, let existingWallet else { return }
        didLoadBalance = true
        let currentBalance = balanceService.currentBalance(for: existingWallet.id)
        if let currentBalance {
            let editableBalance = Self.editableBalance(
                from: currentBalance,
                config: appConfig.config
            )
            balanceText = editableBalance.text
            // Compare future edits with the exact value displayed to the user.
            // A computed Double can contain sub-cent floating-point noise that
            // formatting intentionally hides; saving an untouched form must not
            // move the balance anchor because of that invisible difference.
            initialBalance = editableBalance.value
        }
    }

    private func toggleBalanceSign() {
        if balanceText.hasPrefix("-") {
            balanceText = String(balanceText.dropFirst())
        } else if !balanceText.isEmpty {
            balanceText = "-" + balanceText
        } else {
            balanceText = "-"
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingWallet {
            existingWallet.name = trimmedName
            existingWallet.iconName = selectedIcon
            existingWallet.colorHex = selectedColorHex
            existingWallet.updatedAt = .now
            do {
                let didSetBalance = try Self.saveBalanceIfChanged(
                    parsedBalance: parsedBalance,
                    initialBalance: initialBalance,
                    walletId: existingWallet.id,
                    balanceService: balanceService
                )
                if !didSetBalance {
                    try modelContext.save()
                }
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
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
        do {
            try modelContext.save()
            appConfig.setSelectedWalletScope(.wallet(wallet.id))
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

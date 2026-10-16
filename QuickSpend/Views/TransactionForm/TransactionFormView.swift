import SwiftUI
import SwiftData

/// Full-screen form for adding or editing a transaction, or a transfer
/// between two wallets when the caller passes `onSaveTransfer`.
struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let wallets: [Wallet]
    let defaultWalletId: String
    let existingTransaction: Transaction?
    let existingTransfer: Transfer?
    let onSaveTransfer: ((Transfer) throws -> Void)?
    let onSave: (Transaction) throws -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String?
    @State private var selectedWalletId: String
    @State private var selectedDate: Date
    @State private var selectedType: TransactionType
    @State private var kind: TransactionFormKind
    @State private var fromWalletId: String
    @State private var toWalletId: String

    @State private var amountError: String?
    @State private var categoryError: String?
    @State private var noteError: String?
    @State private var dateError: String?
    @State private var walletError: String?
    @State private var hasAttemptedSave = false
    @State private var saveError: String?

    private var isEditMode: Bool { existingTransaction != nil || existingTransfer != nil }

    private var activeWallets: [Wallet] {
        Self.activeWallets(wallets)
    }

    private var availableKinds: [TransactionFormKind] {
        let editing: TransactionFormKind? = existingTransfer != nil
            ? .transfer
            : existingTransaction.map { TransactionFormKind($0.type) }
        return TransactionFormKind.available(
            editing: editing,
            canTransfer: onSaveTransfer != nil,
            activeWalletCount: activeWallets.count
        )
    }

    private var navigationTitle: String {
        if existingTransfer != nil { return L10n.tr("transfer.edit_title", appConfig.language) }
        if kind == .transfer { return L10n.tr("transfer.title", appConfig.language) }
        return isEditMode
            ? L10n.tr("expense_form.edit_title", appConfig.language)
            : L10n.tr("expense_form.add_title", appConfig.language)
    }

    private var adaptiveBackground: LinearGradient {
        colorScheme == .dark ? AppTheme.darkBackgroundGradient : AppTheme.backgroundGradient
    }

    private var accentColor: Color {
        FormFieldStyle.accent(colorScheme)
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType && !$0.isHidden }
    }

    init(
        categories: [Category],
        wallets: [Wallet] = [],
        defaultWalletId: String = Wallet.personalID,
        expense: Transaction? = nil,
        transfer: Transfer? = nil,
        initialNote: String? = nil,
        onSaveTransfer: ((Transfer) throws -> Void)? = nil,
        onSave: @escaping (Transaction) throws -> Void
    ) {
        self.categories = categories
        self.wallets = wallets
        self.defaultWalletId = defaultWalletId
        self.existingTransaction = expense
        self.existingTransfer = transfer
        self.onSaveTransfer = onSaveTransfer
        self.onSave = onSave

        let amount = transfer?.amount ?? expense?.amount
        _noteText = State(initialValue: transfer?.note ?? expense?.note ?? initialNote ?? "")
        _amountText = State(initialValue: amount.map { String(format: "%.0f", $0) } ?? "")
        _selectedCategoryId = State(initialValue: expense?.categoryId)
        _selectedWalletId = State(initialValue: expense?.walletId ?? defaultWalletId)
        _selectedDate = State(initialValue: transfer?.date ?? expense?.date ?? {
            let now = Date.now
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        }())
        _selectedType = State(initialValue: expense?.type ?? .expense)
        _kind = State(initialValue: transfer != nil ? .transfer : TransactionFormKind(expense?.type ?? .expense))

        let fromId = transfer?.fromWalletId ?? defaultWalletId
        _fromWalletId = State(initialValue: fromId)
        _toWalletId = State(initialValue: transfer?.toWalletId
            ?? Self.activeWallets(wallets).first { $0.id != fromId }?.id
            ?? "")
    }

    private static func activeWallets(_ wallets: [Wallet]) -> [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.spacing24) {
                            if availableKinds.count > 1 {
                                TypeToggle(
                                    selection: $kind,
                                    kinds: availableKinds,
                                    language: appConfig.language
                                )
                            }
                            if kind == .transfer {
                                transferFields
                            } else {
                                transactionFields
                            }
                        }
                        .padding(.horizontal, AppTheme.spacing16)
                        .padding(.top, AppTheme.spacing16)
                        .padding(.bottom, AppTheme.spacing32)
                    }

                    bottomButtons
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .onChange(of: kind) {
                if let type = kind.transactionType { selectedType = type }
            }
            .onChange(of: fromWalletId) {
                if hasAttemptedSave { validateWallets() }
            }
            .onChange(of: toWalletId) {
                if hasAttemptedSave { validateWallets() }
            }
            .onChange(of: selectedType) {
                if let id = selectedCategoryId,
                   !filteredCategories.contains(where: { $0.id == id }) {
                    selectedCategoryId = nil
                }
                if hasAttemptedSave { validateCategory() }
            }
            .onChange(of: amountText) {
                let formatted = appConfig.config.formatAmountInput(amountText)
                if formatted != amountText { amountText = formatted }
                if hasAttemptedSave { validateAmount() }
            }
            .onChange(of: selectedCategoryId) {
                if hasAttemptedSave { validateCategory() }
            }
            .onChange(of: noteText) {
                if hasAttemptedSave { validateNote() }
            }
            .onChange(of: selectedDate) {
                if hasAttemptedSave { validateDate() }
            }
            .alert(
                L10n.tr("transaction.save_error_title", appConfig.language),
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                ),
                presenting: saveError
            ) { _ in
                Button(L10n.tr("common.close", appConfig.language)) { saveError = nil }
            } message: { error in
                Text(error)
            }
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: AppTheme.spacing16) {
            Button {
                dismiss()
            } label: {
                Text(L10n.tr("common.cancel", appConfig.language))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing16)
                    .background(
                        Capsule()
                            .stroke(accentColor, lineWidth: 1.5)
                    )
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)

            Button {
                save()
            } label: {
                Text(L10n.tr("common.save", appConfig.language))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing16)
                    .background(
                        Capsule()
                            .fill(accentColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.spacing16)
        .padding(.vertical, AppTheme.spacing16)
    }

    // MARK: - Fields

    @ViewBuilder
    private var transactionFields: some View {
        if wallets.count > 1 {
            walletPicker(L10n.tr("wallets.wallet", appConfig.language), selection: $selectedWalletId)
        }
        AmountInputField(
            amountText: $amountText,
            currency: appConfig.config.currency,
            error: amountError,
            language: appConfig.language
        )
        CategoryPickerField(
            selectedCategoryId: $selectedCategoryId,
            categories: categories,
            selectedType: selectedType,
            error: categoryError,
            language: appConfig.language
        )
        DateRow(
            selectedDate: $selectedDate,
            error: dateError,
            language: appConfig.language
        )
        NoteField(
            noteText: $noteText,
            error: noteError,
            language: appConfig.language
        )
    }

    @ViewBuilder
    private var transferFields: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            walletPicker(L10n.tr("transfer.from", appConfig.language), selection: $fromWalletId)
            walletPicker(L10n.tr("transfer.to", appConfig.language), selection: $toWalletId)
            if let walletError {
                Text(walletError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        AmountInputField(
            amountText: $amountText,
            currency: appConfig.config.currency,
            error: amountError,
            language: appConfig.language
        )
        DateRow(
            selectedDate: $selectedDate,
            error: dateError,
            language: appConfig.language
        )
        NoteField(
            noteText: $noteText,
            error: nil,
            language: appConfig.language
        )
        Label(L10n.tr("transfer.not_counted", appConfig.language), systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func walletPicker(_ title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                if selection.wrappedValue.isEmpty {
                    Text(L10n.tr("transfer.choose_wallet", appConfig.language)).tag("")
                }
                ForEach(activeWallets, id: \.id) { wallet in
                    Label(wallet.displayName(language: appConfig.language), systemImage: wallet.iconName)
                        .tag(wallet.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.spacing12)
            .padding(.vertical, AppTheme.spacing12)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    // MARK: - Validation

    @discardableResult
    private func validateAmount() -> Bool {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            amountError = L10n.tr("expense_form.amount_required", appConfig.language)
            return false
        }
        guard let amount = appConfig.config.parseAmount(trimmed), amount > 0 else {
            amountError = L10n.tr("expense_form.amount_positive", appConfig.language)
            return false
        }
        amountError = nil
        return true
    }

    @discardableResult
    private func validateCategory() -> Bool {
        if selectedCategoryId == nil {
            categoryError = L10n.tr("expense_form.category_required", appConfig.language)
            return false
        }
        categoryError = nil
        return true
    }

    @discardableResult
    private func validateNote() -> Bool {
        if noteText.trimmingCharacters(in: .whitespaces).isEmpty {
            noteError = L10n.tr("expense_form.note_required", appConfig.language)
            return false
        }
        noteError = nil
        return true
    }

    @discardableResult
    private func validateDate() -> Bool {
        let calendar = Calendar.current
        if calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: Date()) {
            dateError = L10n.tr("expense_form.future_date", appConfig.language)
            return false
        }
        dateError = nil
        return true
    }

    @discardableResult
    private func validateWallets() -> Bool {
        if fromWalletId.isEmpty || toWalletId.isEmpty {
            walletError = L10n.tr("transfer.choose_wallet", appConfig.language)
            return false
        }
        if fromWalletId == toWalletId {
            walletError = L10n.tr("transfer.same_wallet_error", appConfig.language)
            return false
        }
        walletError = nil
        return true
    }

    private func validateAll() -> Bool {
        let results = [
            validateAmount(),
            validateCategory(),
            validateNote(),
            validateDate()
        ]
        return results.allSatisfy { $0 }
    }

    private func save() {
        hasAttemptedSave = true

        if kind == .transfer {
            saveTransfer()
            return
        }

        guard validateAll() else { return }

        let amount = appConfig.config.parseAmount(amountText)!

        let transaction = Transaction(
            id: existingTransaction?.id ?? UUID().uuidString,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId!,
            walletId: selectedWalletId,
            type: selectedType,
            date: selectedDate,
            rawInput: existingTransaction?.rawInput,
            confidence: existingTransaction?.confidence
        )

        do {
            try onSave(transaction)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveTransfer() {
        let results = [validateAmount(), validateWallets(), validateDate()]
        guard results.allSatisfy({ $0 }), let onSaveTransfer,
              let amount = appConfig.config.parseAmount(amountText) else { return }

        let transfer = Transfer(
            id: existingTransfer?.id ?? UUID().uuidString,
            fromWalletId: fromWalletId,
            toWalletId: toWalletId,
            amount: amount,
            date: selectedDate,
            note: noteText.trimmingCharacters(in: .whitespaces)
        )

        do {
            try onSaveTransfer(transfer)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    TransactionFormView(
        categories: CategoryService.defaultCategories(language: "en")
    ) { transaction in
        print("Saved: \(transaction.note) - \(transaction.amount)")
    }
    .environment(AppConfigViewModel())
}

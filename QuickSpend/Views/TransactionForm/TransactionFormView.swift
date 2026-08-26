import SwiftUI
import SwiftData

/// Full-screen form for adding or editing a transaction.
struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let wallets: [Wallet]
    let defaultWalletId: String
    let existingTransaction: Transaction?
    let onSave: (Transaction) throws -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String?
    @State private var selectedWalletId: String
    @State private var selectedDate: Date
    @State private var selectedType: TransactionType

    @State private var amountError: String?
    @State private var categoryError: String?
    @State private var noteError: String?
    @State private var dateError: String?
    @State private var hasAttemptedSave = false
    @State private var saveError: String?

    private var isEditMode: Bool { existingTransaction != nil }

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
        initialNote: String? = nil,
        onSave: @escaping (Transaction) throws -> Void
    ) {
        self.categories = categories
        self.wallets = wallets
        self.defaultWalletId = defaultWalletId
        self.existingTransaction = expense
        self.onSave = onSave

        _noteText = State(initialValue: expense?.note ?? initialNote ?? "")
        _amountText = State(initialValue: expense.map { String(format: "%.0f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: expense?.categoryId)
        _selectedWalletId = State(initialValue: expense?.walletId ?? defaultWalletId)
        _selectedDate = State(initialValue: expense?.date ?? {
            let now = Date.now
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        }())
        _selectedType = State(initialValue: expense?.type ?? .expense)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                adaptiveBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.spacing24) {
                            TypeToggle(
                                selectedType: $selectedType,
                                language: appConfig.language
                            )
                            if wallets.count > 1 {
                                walletPicker
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
                        .padding(.horizontal, AppTheme.spacing16)
                        .padding(.top, AppTheme.spacing16)
                        .padding(.bottom, AppTheme.spacing32)
                    }

                    bottomButtons
                }
            }
            .navigationTitle(isEditMode
                ? L10n.tr("expense_form.edit_title", appConfig.language)
                : L10n.tr("expense_form.add_title", appConfig.language))
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

    private var walletPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("wallets.wallet", appConfig.language))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            Picker(L10n.tr("wallets.wallet", appConfig.language), selection: $selectedWalletId) {
                ForEach(wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { wallet in
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
}

#Preview {
    TransactionFormView(
        categories: CategoryService.defaultCategories(language: "en")
    ) { transaction in
        print("Saved: \(transaction.note) - \(transaction.amount)")
    }
    .environment(AppConfigViewModel())
}

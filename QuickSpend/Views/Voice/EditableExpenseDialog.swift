import SwiftUI

/// Dialog for reviewing and editing AI-parsed transactions before saving
struct EditableExpenseDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let parsedTransactions: [ParsedTransaction]
    let categories: [Category]
    let wallets: [Wallet]
    let defaultWalletId: String
    let onSave: ([Transaction]) throws -> Void

    @State private var editableExpenses: [EditableExpenseData]
    @State private var saveError: String?

    init(
        parsedExpenses: [ParsedTransaction],
        categories: [Category],
        wallets: [Wallet] = [],
        defaultWalletId: String = Wallet.personalID,
        onSave: @escaping ([Transaction]) throws -> Void
    ) {
        self.parsedTransactions = parsedExpenses
        self.categories = categories
        self.wallets = wallets
        self.defaultWalletId = defaultWalletId
        self.onSave = onSave
        _editableExpenses = State(initialValue: parsedExpenses.map { EditableExpenseData(from: $0, walletId: defaultWalletId) })
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(editableExpenses.indices, id: \.self) { index in
                    Section(sectionTitle(index: index)) {
                        expenseForm(at: index)
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.discard", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { save() }
                        .bold()
                }
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

    // MARK: - Titles

    private var navTitle: String {
        if editableExpenses.count > 1 {
            let count = editableExpenses.count
            return L10n.tr("voice_review.transactions_parsed", appConfig.language, count)
        }
        return L10n.tr("voice_review.confirm_title", appConfig.language)
    }

    private func sectionTitle(index: Int) -> String {
        guard editableExpenses.count > 1 else {
            return L10n.tr("voice_review.transaction", appConfig.language)
        }
        return L10n.tr("voice_review.transaction_n", appConfig.language, index + 1)
    }

    // MARK: - Expense Form

    private var activeWallets: [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func expenseForm(at index: Int) -> some View {
        if editableExpenses[index].toWalletId != nil {
            transferForm(at: index)
        } else {
            categorizedForm(at: index)
        }
    }

    /// A wallet-to-wallet transfer heard in the voice input.
    @ViewBuilder
    private func transferForm(at index: Int) -> some View {
        Label(L10n.tr("transfer.title", appConfig.language), systemImage: Transfer.iconName)
            .foregroundStyle(AppTheme.accentTeal)

        walletPicker(L10n.tr("transfer.from", appConfig.language), selection: $editableExpenses[index].walletId)
        walletPicker(
            L10n.tr("transfer.to", appConfig.language),
            selection: Binding(
                get: { editableExpenses[index].toWalletId ?? "" },
                set: { editableExpenses[index].toWalletId = $0 }
            )
        )

        TextField(L10n.tr("common.description", appConfig.language), text: $editableExpenses[index].note)
            .textInputAutocapitalization(.sentences)
        amountField(at: index)
        dateField(at: index)
        lowConfidenceWarning(editableExpenses[index].confidence)
    }

    private func walletPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            if selection.wrappedValue.isEmpty {
                Text(L10n.tr("transfer.choose_wallet", appConfig.language)).tag("")
            }
            ForEach(activeWallets, id: \.id) { wallet in
                Label(wallet.displayName(language: appConfig.language), systemImage: wallet.iconName)
                    .tag(wallet.id)
            }
        }
    }

    @ViewBuilder
    private func categorizedForm(at index: Int) -> some View {
        let data = editableExpenses[index]
        let filteredCategories = categories.filter { $0.type == data.type && !$0.isHidden }

        // Type
        TransactionTypePicker(selection: $editableExpenses[index].type, language: appConfig.language)
        .onChange(of: editableExpenses[index].type) {
            // Reset category when type changes
            let filtered = categories.filter { $0.type == editableExpenses[index].type }
            if !filtered.contains(where: { $0.id == editableExpenses[index].categoryId }) {
                editableExpenses[index].categoryId = filtered.first?.id ?? "other_expense"
            }
        }

        if wallets.count > 1 {
            Picker(L10n.tr("wallets.wallet", appConfig.language), selection: $editableExpenses[index].walletId) {
                ForEach(wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { wallet in
                    Label(wallet.displayName(language: appConfig.language), systemImage: wallet.iconName)
                        .tag(wallet.id)
                }
            }
        }

        // Note
        TextField(L10n.tr("common.description", appConfig.language), text: $editableExpenses[index].note)
            .textInputAutocapitalization(.sentences)

        amountField(at: index)

        // Category
        Picker(L10n.tr("common.category", appConfig.language), selection: $editableExpenses[index].categoryId) {
            ForEach(filteredCategories, id: \.id) { category in
                HStack {
                    Image(systemName: category.iconName)
                    Text(category.name)
                }
                .tag(category.id)
            }
        }

        dateField(at: index)
        lowConfidenceWarning(data.confidence)
    }

    private func amountField(at index: Int) -> some View {
        HStack {
            Text(appConfig.config.currencySymbol)
                .font(.body.bold())
                .foregroundStyle(.secondary)
            TextField(L10n.tr("common.amount", appConfig.language), text: $editableExpenses[index].amountText)
                .keyboardType(.decimalPad)
                .font(.body.monospacedDigit())
                .onChange(of: editableExpenses[index].amountText) {
                    let formatted = appConfig.config.formatAmountInput(editableExpenses[index].amountText)
                    if formatted != editableExpenses[index].amountText {
                        editableExpenses[index].amountText = formatted
                    }
                }
        }
    }

    private func dateField(at index: Int) -> some View {
        DatePicker(
            L10n.tr("common.date", appConfig.language),
            selection: $editableExpenses[index].date,
            in: ...Date(),
            displayedComponents: [.date]
        )
    }

    @ViewBuilder
    private func lowConfidenceWarning(_ confidence: Double) -> some View {
        if confidence < AppConstants.confidenceWarningThreshold {
            HStack(spacing: AppTheme.spacing8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warning)
                    .font(.caption)
                Text(L10n.tr("voice_review.low_confidence", appConfig.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Save

    private func save() {
        let hasIncompleteTransfer = editableExpenses.contains { data in
            guard let destination = data.toWalletId else { return false }
            return destination.isEmpty || destination == data.walletId
        }
        guard !hasIncompleteTransfer else {
            saveError = L10n.tr("voice_review.transfer_incomplete", appConfig.language)
            return
        }

        let transactions = editableExpenses.flatMap { data -> [Transaction] in
            guard let amount = parseAmount(data.amountText), amount > 0 else { return [] }
            let clampedAmount = min(amount, AppConstants.maxExpenseAmount)
            let note = data.note.trimmingCharacters(in: .whitespaces)

            if let destination = data.toWalletId {
                return Transfer(
                    fromWalletId: data.walletId,
                    toWalletId: destination,
                    amount: clampedAmount,
                    date: data.date,
                    note: note
                ).makeLegs()
            }

            guard !note.isEmpty else { return [] }
            return [Transaction(
                amount: clampedAmount,
                note: note,
                categoryId: data.categoryId,
                walletId: data.walletId,
                type: data.type,
                date: data.date,
                rawInput: data.rawInput,
                confidence: data.confidence
            )]
        }

        guard !transactions.isEmpty else { return }
        do {
            try onSave(transactions)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func parseAmount(_ text: String) -> Double? {
        appConfig.config.parseAmount(text)
    }
}

// MARK: - Editable Data

struct EditableExpenseData {
    var note: String
    var amountText: String
    var categoryId: String
    var walletId: String
    /// Set for a transfer; empty until the user picks the destination.
    var toWalletId: String?
    var type: TransactionType
    var date: Date
    var confidence: Double
    var rawInput: String

    init(from parsed: ParsedTransaction, walletId: String = Wallet.personalID) {
        self.note = parsed.note
        self.amountText = String(format: parsed.amount == floor(parsed.amount) ? "%.0f" : "%.2f", parsed.amount)
        self.categoryId = parsed.categoryId
        self.walletId = parsed.walletId ?? walletId
        self.toWalletId = parsed.transferToWalletId
        self.type = parsed.type
        self.date = parsed.date
        self.confidence = parsed.confidence
        self.rawInput = parsed.rawInput ?? parsed.note
    }
}

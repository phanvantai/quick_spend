import SwiftUI
import SwiftData

/// Full-screen form for adding or editing a transaction
struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let existingTransaction: Transaction?
    let onSave: (Transaction) -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String?
    @State private var selectedDate: Date
    @State private var selectedType: TransactionType

    // Validation states
    @State private var amountError: String?
    @State private var categoryError: String?
    @State private var noteError: String?
    @State private var dateError: String?
    @State private var hasAttemptedSave = false

    @State private var showCategoryPicker = false
    @State private var showDatePicker = false

    private var isEditMode: Bool { existingTransaction != nil }

    private var adaptiveBackground: LinearGradient {
        colorScheme == .dark ? AppTheme.darkBackgroundGradient : AppTheme.backgroundGradient
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground)
    }

    private var fieldBorder: Color {
        colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)
    }

    private var accentColor: Color {
        colorScheme == .dark ? AppTheme.primaryLight : AppTheme.primaryMint
    }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType && !$0.isHidden }
    }

    private var selectedCategory: Category? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }

    /// Categories grouped by CategoryGroup for the picker sheet
    private var groupedCategories: [(group: CategoryGroup, categories: [Category])] {
        let grouped = Dictionary(grouping: filteredCategories) { $0.group ?? .other }
        let groupOrder: [CategoryGroup] = selectedType == .expense
            ? [.dailyLiving, .personal, .social, .financial, .other]
            : [.earned, .passive, .received, .other]
        return groupOrder.compactMap { group in
            guard let cats = grouped[group], !cats.isEmpty else { return nil }
            return (group: group, categories: cats.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    init(
        categories: [Category],
        expense: Transaction? = nil,
        onSave: @escaping (Transaction) -> Void
    ) {
        self.categories = categories
        self.existingTransaction = expense
        self.onSave = onSave

        _noteText = State(initialValue: expense?.note ?? "")
        _amountText = State(initialValue: expense.map { String(format: "%.0f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: expense?.categoryId)
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
                            typeToggle
                            amountField
                            categoryField
                            dateField
                            noteField
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
                // Reset category when type changes
                if let id = selectedCategoryId,
                   !filteredCategories.contains(where: { $0.id == id }) {
                    selectedCategoryId = nil
                }
                if hasAttemptedSave { validateCategory() }
            }
            .onChange(of: amountText) {
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
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 0) {
            typeButton(.expense, label: L10n.tr("common.expense", appConfig.language))
            typeButton(.income, label: L10n.tr("common.income", appConfig.language))
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusXLarge)
                .fill(Color(.systemGray6))
        )
    }

    private func typeButton(_ type: TransactionType, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacing12)
                .background {
                    if selectedType == type {
                        Capsule()
                            .fill(accentColor)
                    }
                }
                .foregroundStyle(selectedType == type ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.transaction_amount", appConfig.language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            HStack {
                TextField(
                    L10n.tr("expense_form.enter_amount", appConfig.language),
                    text: $amountText
                )
                .keyboardType(.numberPad)
                .font(.body)

                Text(appConfig.config.currency)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(amountError != nil ? Color.red : fieldBorder, lineWidth: 1)
            )

            if let error = amountError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Category Field

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(selectedType == .expense
                 ? L10n.tr("expense_form.expense_category", appConfig.language)
                 : L10n.tr("expense_form.income_category", appConfig.language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Button {
                showCategoryPicker = true
            } label: {
                HStack {
                    if let category = selectedCategory {
                        HStack(spacing: AppTheme.spacing8) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(category.color)
                            Text(category.name)
                                .foregroundStyle(.primary)
                        }
                    } else {
                        Text(L10n.tr("expense_form.select_category", appConfig.language))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(fieldBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(categoryError != nil ? Color.red : fieldBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let error = categoryError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Date Field

    private var dateField: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.transaction_date", appConfig.language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Button {
                showDatePicker = true
            } label: {
                HStack {
                    Text(formattedDate)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(fieldBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(dateError != nil ? Color.red : fieldBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let error = dateError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Note Field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.note", appConfig.language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            TextField(
                L10n.tr("expense_form.enter_note", appConfig.language),
                text: $noteText
            )
            .textInputAutocapitalization(.sentences)
            .font(.body)
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(noteError != nil ? Color.red : fieldBorder, lineWidth: 1)
            )

            if let error = noteError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Bottom Buttons

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

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(accentColor)
            .labelsHidden()
            .padding()
            .navigationTitle(L10n.tr("expense_form.transaction_date", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Category Picker Sheet

    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(groupedCategories, id: \.group) { section in
                    Section(groupName(for: section.group)) {
                        ForEach(section.categories, id: \.id) { category in
                            Button {
                                selectedCategoryId = category.id
                                showCategoryPicker = false
                            } label: {
                                HStack(spacing: AppTheme.spacing12) {
                                    Image(systemName: category.iconName)
                                        .font(.title3)
                                        .foregroundStyle(category.color)
                                        .frame(width: 32, alignment: .center)

                                    Text(category.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if category.id == selectedCategoryId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(selectedType == .expense
                ? L10n.tr("expense_form.expense_category", appConfig.language)
                : L10n.tr("expense_form.income_category", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) {
                        showCategoryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Localized group name
    private func groupName(for group: CategoryGroup) -> String {
        let key: String
        switch group {
        case .dailyLiving: key = "category_group.daily_living"
        case .personal: key = "category_group.personal"
        case .social: key = "category_group.social"
        case .financial: key = "category_group.financial"
        case .earned: key = "category_group.earned"
        case .passive: key = "category_group.passive"
        case .received: key = "category_group.received"
        case .other: key = "category_group.other"
        }
        return L10n.tr(key, appConfig.language)
    }

    // MARK: - Validation

    @discardableResult
    private func validateAmount() -> Bool {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            amountError = L10n.tr("expense_form.amount_required", appConfig.language)
            return false
        }
        let cleaned = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let amount = Double(cleaned), amount > 0 else {
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
        if selectedDate > Date() {
            dateError = L10n.tr("expense_form.future_date", appConfig.language)
            return false
        }
        dateError = nil
        return true
    }

    private func validateAll() -> Bool {
        // Run all validations (don't short-circuit so all errors show)
        let results = [
            validateAmount(),
            validateCategory(),
            validateNote(),
            validateDate()
        ]
        return results.allSatisfy { $0 }
    }

    // MARK: - Save

    private func save() {
        hasAttemptedSave = true

        guard validateAll() else { return }

        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
        let amount = Double(cleaned)!

        let transaction = Transaction(
            id: existingTransaction?.id ?? UUID().uuidString,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId!,
            type: selectedType,
            date: selectedDate,
            rawInput: existingTransaction?.rawInput,
            confidence: existingTransaction?.confidence
        )

        onSave(transaction)
        dismiss()
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

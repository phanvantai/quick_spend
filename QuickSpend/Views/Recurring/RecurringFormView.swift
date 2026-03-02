import SwiftUI

/// Form for adding or editing a recurring expense template
struct RecurringFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let existingTemplate: RecurringTemplate?
    let onSave: (RecurringTemplate) -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String
    @State private var selectedType: TransactionType
    @State private var selectedPattern: RecurrencePattern
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    @State private var showAmountError = false

    private var isEditMode: Bool { existingTemplate != nil }
    private var isVi: Bool { appConfig.language == "vi" }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType }
    }

    init(
        categories: [Category],
        existingTemplate: RecurringTemplate? = nil,
        onSave: @escaping (RecurringTemplate) -> Void
    ) {
        self.categories = categories
        self.existingTemplate = existingTemplate
        self.onSave = onSave

        _noteText = State(initialValue: existingTemplate?.note ?? "")
        _amountText = State(initialValue: existingTemplate.map { String(format: "%.2f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: existingTemplate?.categoryId ?? "other_expense")
        _selectedType = State(initialValue: existingTemplate?.type ?? .expense)
        _selectedPattern = State(initialValue: existingTemplate?.pattern ?? .monthly)
        _startDate = State(initialValue: existingTemplate?.startDate ?? .now)
        _hasEndDate = State(initialValue: existingTemplate?.endDate != nil)
        _endDate = State(initialValue: existingTemplate?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction type
                Section {
                    Picker(isVi ? "Loại" : "Type", selection: $selectedType) {
                        Text(isVi ? "Chi tiêu" : "Expense").tag(TransactionType.expense)
                        Text(isVi ? "Thu nhập" : "Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Description
                Section(isVi ? "Mô tả" : "Description") {
                    TextField(isVi ? "VD: Tiền nhà, Netflix" : "e.g. Monthly rent, Netflix", text: $noteText)
                        .textInputAutocapitalization(.sentences)
                }

                // Amount
                Section(isVi ? "Số tiền" : "Amount") {
                    HStack {
                        Text(appConfig.config.currencySymbol)
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                    }
                    if showAmountError {
                        Text(isVi ? "Vui lòng nhập số tiền hợp lệ" : "Please enter a valid amount")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Category
                Section(isVi ? "Danh mục" : "Category") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 90), spacing: AppTheme.spacing8)
                    ], spacing: AppTheme.spacing8) {
                        ForEach(filteredCategories, id: \.id) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Recurrence pattern
                Section(isVi ? "Tần suất" : "Recurrence") {
                    Picker(isVi ? "Chu kỳ" : "Pattern", selection: $selectedPattern) {
                        Text(isVi ? "Ngày" : "Daily").tag(RecurrencePattern.daily)
                        Text(isVi ? "Tuần" : "Weekly").tag(RecurrencePattern.weekly)
                        Text(isVi ? "Tháng" : "Monthly").tag(RecurrencePattern.monthly)
                        Text(isVi ? "Năm" : "Yearly").tag(RecurrencePattern.yearly)
                    }
                    .pickerStyle(.segmented)
                }

                // Dates
                Section(isVi ? "Lịch trình" : "Schedule") {
                    DatePicker(
                        isVi ? "Ngày bắt đầu" : "Start Date",
                        selection: $startDate,
                        displayedComponents: [.date]
                    )

                    Toggle(isVi ? "Có ngày kết thúc" : "Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            isVi ? "Ngày kết thúc" : "End Date",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle(isEditMode
                ? (isVi ? "Sửa định kỳ" : "Edit Recurring")
                : (isVi ? "Thêm định kỳ" : "Add Recurring"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isVi ? "Hủy" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isVi ? "Lưu" : "Save") { save() }
                        .bold()
                        .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedType) {
                if !filteredCategories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = filteredCategories.first?.id ?? "other_expense"
                }
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ category: Category) -> some View {
        let isSelected = category.id == selectedCategoryId
        return Button {
            selectedCategoryId = category.id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.spacing8)
            .padding(.vertical, AppTheme.spacing8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(isSelected ? category.color.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .stroke(isSelected ? category.color : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? category.color : .primary)
    }

    // MARK: - Save

    private func save() {
        let cleanedAmount = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let amount = Double(cleanedAmount), amount > 0 else {
            showAmountError = true
            return
        }
        showAmountError = false

        let template = RecurringTemplate(
            id: existingTemplate?.id ?? UUID().uuidString,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId,
            type: selectedType,
            pattern: selectedPattern,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            lastGeneratedDate: existingTemplate?.lastGeneratedDate,
            isActive: existingTemplate?.isActive ?? true
        )

        onSave(template)
        dismiss()
    }
}

#Preview {
    RecurringFormView(
        categories: CategoryService.defaultCategories(language: "en")
    ) { template in
        print("Saved: \(template.note)")
    }
    .environment(AppConfigViewModel())
}

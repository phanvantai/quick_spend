import SwiftUI
import SwiftData

/// List of recurring expense templates with active/inactive toggle
struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \RecurringTemplate.startDate, order: .reverse) private var templates: [RecurringTemplate]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showingAddForm = false
    @State private var editingTemplate: RecurringTemplate?
    @State private var deletingTemplate: RecurringTemplate?

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Recurring Templates",
                    systemImage: "repeat",
                    description: Text("Create a template to automatically generate expenses on a schedule.")
                )
            } else {
                ForEach(templates, id: \.id) { template in
                    templateRow(template)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletingTemplate = template
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingTemplate = template
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(AppTheme.primaryMint)
                        }
                }
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            RecurringFormView(categories: categories) { newTemplate in
                modelContext.insert(newTemplate)
            }
        }
        .sheet(item: $editingTemplate) { template in
            RecurringFormView(categories: categories, existingTemplate: template) { updated in
                template.amount = updated.amount
                template.note = updated.note
                template.categoryId = updated.categoryId
                template.type = updated.type
                template.pattern = updated.pattern
                template.startDate = updated.startDate
                template.endDate = updated.endDate
                template.updatedAt = .now
            }
        }
        .alert("Delete Template", isPresented: .init(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingTemplate = nil }
            Button("Delete", role: .destructive) {
                if let template = deletingTemplate {
                    modelContext.delete(template)
                    deletingTemplate = nil
                }
            }
        } message: {
            if let template = deletingTemplate {
                Text("Delete \"\(template.note)\"? Previously generated transactions will not be removed.")
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: RecurringTemplate) -> some View {
        let category = categories.first { $0.id == template.categoryId }

        return HStack(spacing: AppTheme.spacing12) {
            // Category icon
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill((category?.color ?? .secondary).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: category?.iconName ?? "questionmark.circle")
                        .foregroundStyle(category?.color ?? .secondary)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(template.note)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: AppTheme.spacing4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                    Text(patternLabel(template.pattern))
                        .font(.caption)

                    Text("·")

                    Text(template.startDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Amount and toggle
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(template.type == .income ? "+" : "-")\(appConfig.formatCurrency(template.amount))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(template.type == .income ? AppTheme.incomeColor : AppTheme.expenseColor)

                Toggle("", isOn: Binding(
                    get: { template.isActive },
                    set: { template.isActive = $0 }
                ))
                .labelsHidden()
                .scaleEffect(0.8)
                .tint(AppTheme.primaryMint)
            }
        }
        .padding(.vertical, 2)
        .opacity(template.isActive ? 1 : 0.5)
    }

    private func patternLabel(_ pattern: RecurrencePattern) -> String {
        switch pattern {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

#Preview {
    NavigationStack {
        RecurringListView()
    }
    .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
    .environment(AppConfigViewModel())
}

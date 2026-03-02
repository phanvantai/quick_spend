import SwiftUI
import SwiftData

/// List of recurring expense templates with active/inactive toggle
struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \RecurringTemplate.startDate, order: .reverse) private var templates: [RecurringTemplate]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showingAddForm = false
    @State private var editingTemplate: RecurringTemplate?
    @State private var deletingTemplate: RecurringTemplate?
    @State private var showLimitAlert = false
    @State private var showPaywall = false

    private var isVi: Bool { appConfig.language == "vi" }

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    isVi ? "Chưa có mẫu định kỳ" : "No Recurring Templates",
                    systemImage: "repeat",
                    description: Text(isVi
                        ? "Tạo mẫu để tự động sinh giao dịch theo lịch."
                        : "Create a template to automatically generate transactions on a schedule.")
                )
            } else {
                ForEach(templates, id: \.id) { template in
                    templateRow(template)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletingTemplate = template
                            } label: {
                                Label(isVi ? "Xóa" : "Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingTemplate = template
                            } label: {
                                Label(isVi ? "Sửa" : "Edit", systemImage: "pencil")
                            }
                            .tint(AppTheme.primaryMint)
                        }
                }
            }
        }
        .navigationTitle(isVi ? "Định kỳ" : "Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if subscription.canAddRecurringTemplate(currentCount: templates.count) {
                        showingAddForm = true
                    } else {
                        showLimitAlert = true
                    }
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
        .alert(
            isVi ? "Xóa mẫu" : "Delete Template",
            isPresented: .init(
                get: { deletingTemplate != nil },
                set: { if !$0 { deletingTemplate = nil } }
            )
        ) {
            Button(isVi ? "Hủy" : "Cancel", role: .cancel) { deletingTemplate = nil }
            Button(isVi ? "Xóa" : "Delete", role: .destructive) {
                if let template = deletingTemplate {
                    modelContext.delete(template)
                    deletingTemplate = nil
                }
            }
        } message: {
            if let template = deletingTemplate {
                Text(isVi
                     ? "Xóa \"\(template.note)\"? Các giao dịch đã tạo trước đó sẽ không bị xóa."
                     : "Delete \"\(template.note)\"? Previously generated transactions will not be removed.")
            }
        }
        .alert(
            isVi ? "Đã đạt giới hạn" : "Limit Reached",
            isPresented: $showLimitAlert
        ) {
            Button(isVi ? "Nâng cấp Pro" : "Upgrade to Pro") {
                showPaywall = true
            }
            Button(isVi ? "Hủy" : "Cancel", role: .cancel) { }
        } message: {
            Text(isVi
                 ? "Gói miễn phí giới hạn \(AppConstants.freeTierRecurringTemplatesLimit) mẫu định kỳ. Nâng cấp Pro để không giới hạn."
                 : "Free plan allows \(AppConstants.freeTierRecurringTemplatesLimit) recurring templates. Upgrade to Pro for unlimited.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
        if isVi {
            switch pattern {
            case .daily: return "Hàng ngày"
            case .weekly: return "Hàng tuần"
            case .monthly: return "Hàng tháng"
            case .yearly: return "Hàng năm"
            }
        }
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
    .environment(SubscriptionViewModel())
}

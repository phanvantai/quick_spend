import SwiftUI
import SwiftData

/// List of recurring expense templates with active/inactive toggle
struct RecurringListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \RecurringTemplate.startDate, order: .reverse) private var templates: [RecurringTemplate]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var showingAddForm = false
    @State private var editingTemplate: RecurringTemplate?
    @State private var deletingTemplate: RecurringTemplate?
    @State private var showLimitAlert = false
    @State private var showPaywall = false

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(
                    L10n.tr("recurring.no_templates", appConfig.language),
                    systemImage: "repeat",
                    description: Text(L10n.tr("recurring.no_templates_desc", appConfig.language))
                )
            } else {
                ForEach(templates, id: \.id) { template in
                    templateRow(template)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingTemplate = template
                            } label: {
                                Label(L10n.tr("common.delete", appConfig.language), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingTemplate = template
                            } label: {
                                Label(L10n.tr("common.edit", appConfig.language), systemImage: "pencil")
                            }
                            .tint(AppTheme.adaptiveAccent(colorScheme))
                        }
                }
            }
        }
        .navigationTitle(L10n.tr("recurring.title", appConfig.language))
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
            RecurringFormView(
                categories: categories,
                wallets: activeWallets,
                defaultWalletId: defaultWalletId
            ) { newTemplate in
                try RecurringTemplatePersistence.create(newTemplate, in: modelContext)
            }
        }
        .sheet(item: $editingTemplate) { template in
            RecurringFormView(
                categories: categories,
                wallets: activeWallets,
                defaultWalletId: defaultWalletId,
                existingTemplate: template
            ) { updated in
                try RecurringTemplatePersistence.update(
                    template,
                    with: updated,
                    in: modelContext
                )
            }
        }
        .alert(
            L10n.tr("recurring.delete_title", appConfig.language),
            isPresented: .init(
                get: { deletingTemplate != nil },
                set: { if !$0 { deletingTemplate = nil } }
            )
        ) {
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { deletingTemplate = nil }
            Button(L10n.tr("common.delete", appConfig.language), role: .destructive) {
                if let template = deletingTemplate {
                    modelContext.delete(template)
                    deletingTemplate = nil
                }
            }
        } message: {
            if let template = deletingTemplate {
                Text(L10n.tr("recurring.delete_message", appConfig.language, template.note))
            }
        }
        .alert(
            L10n.tr("recurring.limit_title", appConfig.language),
            isPresented: $showLimitAlert
        ) {
            Button(L10n.tr("common.upgrade_premium", appConfig.language)) {
                showPaywall = true
            }
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
        } message: {
            Text(L10n.tr("recurring.limit_message", appConfig.language, AppConstants.freeTierRecurringTemplatesLimit))
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .tint(AppTheme.adaptiveAccent(colorScheme))
    }

    // MARK: - Template Row

    private var activeWallets: [Wallet] {
        WalletService.activeWallets(from: wallets)
    }

    private var defaultWalletId: String {
        WalletService.resolvedDefaultWalletId(wallets: activeWallets)
    }

    private func templateRow(_ template: RecurringTemplate) -> some View {
        let category = categories.first { $0.id == template.categoryId }

        return HStack(spacing: AppTheme.spacing12) {
            // Category icon
            CategoryIconBadge(
                iconName: category?.iconName ?? "questionmark.circle",
                color: category?.color ?? .secondary,
                size: 44
            )

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
                .tint(AppTheme.adaptiveAccent(colorScheme))
            }
        }
        .padding(.vertical, 2)
        .opacity(template.isActive ? 1 : 0.5)
    }

    private func patternLabel(_ pattern: RecurrencePattern) -> String {
        switch pattern {
        case .daily: return L10n.tr("recurring.daily", appConfig.language)
        case .weekly: return L10n.tr("recurring.weekly", appConfig.language)
        case .monthly: return L10n.tr("recurring.monthly", appConfig.language)
        case .yearly: return L10n.tr("recurring.yearly", appConfig.language)
        }
    }
}

#Preview {
    NavigationStack {
        RecurringListView()
    }
    .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self, Wallet.self], inMemory: true)
    .environment(AppConfigViewModel())
    .environment(SubscriptionViewModel())
}

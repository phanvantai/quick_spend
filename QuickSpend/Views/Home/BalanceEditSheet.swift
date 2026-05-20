import SwiftUI
import SwiftData

/// Sheet for setting or editing the user's opening balance.
///
/// On save:
/// - If no anchor exists, creates one with `openingBalance = entered amount` and
///   `anchorDate = startOfDay(now)`.
/// - If an anchor exists, updates both fields — editing the balance is interpreted
///   as "this is my balance as of now", so the anchor moment moves to today and
///   transactions from before the new anchor are excluded from the running total.
struct BalanceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balanceService

    @Query private var anchors: [BalanceAnchor]

    @State private var amountText: String = ""
    @FocusState private var amountFocused: Bool

    private var existingAnchor: BalanceAnchor? { anchors.first }

    private var hasExistingAnchor: Bool { existingAnchor != nil }

    private var parsedAmount: Double? {
        appConfig.config.parseAmount(amountText)
    }

    private var canSave: Bool { parsedAmount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: AppTheme.spacing8) {
                        Text(appConfig.config.currencySymbol)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField(
                            L10n.tr("balance.edit_placeholder", appConfig.language),
                            text: $amountText
                        )
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .focused($amountFocused)
                        .onChange(of: amountText) { _, new in
                            // Live-format with locale-aware grouping separators, same
                            // pattern TransactionFormView uses.
                            let formatted = appConfig.config.formatAmountInput(new)
                            if formatted != new {
                                amountText = formatted
                            }
                        }
                    }
                } header: {
                    Text(L10n.tr("balance.edit_label", appConfig.language))
                } footer: {
                    Text(L10n.tr(
                        hasExistingAnchor ? "balance.edit_hint_existing" : "balance.edit_hint_new",
                        appConfig.language
                    ))
                }
            }
            .navigationTitle(L10n.tr(
                hasExistingAnchor ? "balance.edit_title" : "balance.setup_title",
                appConfig.language
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel", appConfig.language)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let anchor = existingAnchor {
                    amountText = appConfig.config.formatNumber(anchor.openingBalance)
                }
                amountFocused = true
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let newAnchorDate = Calendar.current.startOfDay(for: Date())

        if let existing = existingAnchor {
            existing.openingBalance = amount
            existing.anchorDate = newAnchorDate
        } else {
            let anchor = BalanceAnchor(
                openingBalance: amount,
                anchorDate: newAnchorDate
            )
            modelContext.insert(anchor)
        }

        do {
            try modelContext.save()
            // willSave fires for BalanceAnchor too — but our observer filters for
            // Transaction-only changes. Trigger an explicit recompute so the
            // BalanceCard updates immediately instead of waiting for the next save.
            try? balanceService.recomputeNow()
        } catch {
            print("[BalanceEditSheet] Failed to save anchor: \(error)")
        }

        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return BalanceEditSheet()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}

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

    /// Sort by createdAt ascending to match `BalanceService.fetchAnchor` — under
    /// a CloudKit-induced multi-row state, both must agree on which anchor is
    /// "the" anchor or the user can edit one row and have the recovery sweep
    /// delete it on next recompute.
    @Query(sort: \BalanceAnchor.createdAt, order: .forward)
    private var anchors: [BalanceAnchor]

    @State private var amountText: String = ""
    @State private var saveError: String?
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
            .alert(
                L10n.tr("balance.edit_error_title", appConfig.language),
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

    private func save() {
        guard let amount = parsedAmount else { return }
        // Use the exact moment the user confirmed their balance, not start-of-day.
        // startOfDay double-counts today's earlier transactions: a user logging
        // lunch at noon then setting balance at 3pm would have lunch subtracted
        // again from the new opening. `Date()` makes the predicate exclude any
        // transaction logged before this confirmation.
        let newAnchorDate = Date()

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
            try? balanceService.recomputeNow()
            dismiss()
        } catch {
            // Surface the failure instead of silently dismissing — otherwise the
            // user thinks their balance was saved when CloudKit/disk write failed.
            saveError = error.localizedDescription
        }
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

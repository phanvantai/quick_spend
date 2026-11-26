import SwiftUI

/// Paste one alert and see how QuickSpend reads it, without saving anything.
/// From here the user can also teach QuickSpend a new format ("Learn from a
/// sample"): pick the amount, name the bank, save.
struct BankAlertTryView: View {
    @Environment(AppConfigViewModel.self) private var appConfig

    let store: BankAlertStore

    @State private var text = ""
    @State private var result: BankAlert?
    @State private var didTry = false
    @State private var candidates: [BankAlertTemplateBuilder.Candidate] = []
    @State private var selectedAmount: BankAlertTemplateBuilder.Candidate?
    @State private var fixedType: TransactionType = .expense
    @State private var bankName = ""
    @State private var learnMessage: String?
    @State private var learnFailed = false
    @FocusState private var focused: Bool

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .focused($focused)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(t("bank_alert.try.placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first {
                            text = first
                            read()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    Spacer()
                    Button(t("bank_alert.try.read")) { read() }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryGreen)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } footer: {
                Text(t("bank_alert.try.footer"))
            }

            if didTry {
                Section(t("bank_alert.try.result")) {
                    if let alert = result {
                        resultRows(alert)
                    } else {
                        Label(t("bank_alert.try.not_recognized"), systemImage: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                // Offer to learn only what can't be read yet (keep it visible
                // right after saving, for the confirmation).
                if result == nil || learnMessage != nil {
                    learnSection
                }
            }
        }
        .navigationTitle(t("bank_alert.try.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Result

    @ViewBuilder
    private func resultRows(_ alert: BankAlert) -> some View {
        LabeledContent(t("bank_alert.try.type"), value: t(alert.type == .income ? "common.income" : "common.expense"))
        LabeledContent(t("bank_alert.try.amount"), value: appConfig.config.formatCurrency(alert.amount))
        LabeledContent(t("bank_alert.try.time"), value: alert.date.formatted(date: .abbreviated, time: .standard))
        LabeledContent(t("bank_alert.try.note"), value: alert.note)
        LabeledContent(t("bank_alert.try.bank"), value: alert.bank?.name ?? t("bank_alert.try.unknown_bank"))
        Label(
            t(alert.isVerified ? "bank_alert.try.will_save" : "bank_alert.try.will_review"),
            systemImage: alert.isVerified ? "checkmark.circle.fill" : "tray.full.fill"
        )
        .foregroundStyle(alert.isVerified ? AppTheme.incomeColor : AppTheme.accentOrange)
    }

    // MARK: - Learn from a sample

    @ViewBuilder
    private var learnSection: some View {
        Section {
            if candidates.isEmpty {
                Text(t("bank_alert.learn.no_numbers"))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                    Text(t("bank_alert.learn.pick_amount"))
                        .font(.subheadline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacing8) {
                            ForEach(candidates) { candidate in
                                amountChip(candidate)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                if let selectedAmount, !selectedAmount.hasSign {
                    Picker(t("bank_alert.try.type"), selection: $fixedType) {
                        Text(t("common.expense")).tag(TransactionType.expense)
                        Text(t("common.income")).tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                TextField(t("bank_alert.learn.bank_name"), text: $bankName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button {
                    learn()
                } label: {
                    Label(t("bank_alert.learn.save"), systemImage: "square.and.arrow.down")
                }
                .disabled(selectedAmount == nil || bankName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let learnMessage {
                Label(learnMessage, systemImage: learnFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(learnFailed ? AppTheme.expenseColor : AppTheme.incomeColor)
                    .font(.subheadline)
            }
        } header: {
            Text(t("bank_alert.learn.header"))
        } footer: {
            Text(L10n.tr("bank_alert.learn.footer", language, BankAlertTemplate.trustThreshold))
        }
    }

    private func amountChip(_ candidate: BankAlertTemplateBuilder.Candidate) -> some View {
        let selected = selectedAmount == candidate
        return Button {
            selectedAmount = candidate
            learnMessage = nil
        } label: {
            Text(candidate.text)
                .font(.subheadline.monospacedDigit().weight(selected ? .semibold : .regular))
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? .white : .primary)
                .background(Capsule().fill(selected ? AppTheme.primaryGreen : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func read() {
        focused = false
        result = BankAlertParser.parse(text, templates: store.templates)
        candidates = BankAlertTemplateBuilder.candidates(in: text)
        selectedAmount = candidates.first(where: \.hasSign)
        learnMessage = nil
        didTry = true
    }

    private func learn() {
        guard let selectedAmount else { return }
        do {
            let template = try BankAlertTemplateBuilder.build(
                sample: text, amount: selectedAmount, fixedType: fixedType, bankName: bankName
            )
            store.addTemplate(template)
            learnFailed = false
            learnMessage = L10n.tr("bank_alert.learn.saved", language, template.bankName)
            result = BankAlertParser.parse(text, templates: store.templates)
        } catch BankAlertTemplateBuilder.BuildError.tooGeneric {
            learnFailed = true
            learnMessage = t("bank_alert.learn.error_generic")
        } catch {
            learnFailed = true
            learnMessage = t("bank_alert.learn.error")
        }
    }
}

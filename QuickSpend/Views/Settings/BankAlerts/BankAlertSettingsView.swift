import SwiftUI
import SwiftData

/// Settings → "Bank alerts": turn the feature on or off, see what is
/// supported, open the setup guides and the review list, manage learned
/// formats, choose a wallet per bank, and try the parser on a pasted alert.
struct BankAlertSettingsView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var transactions: [Transaction]

    @State private var store = BankAlertStore()
    @State private var showPaywall = false

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }

    private var activeWallets: [Wallet] { WalletService.activeWallets(from: wallets) }

    var body: some View {
        List {
            if appConfig.currency.uppercased() != "VND" {
                Section {
                    Label(L10n.tr("bank_alert.settings.currency_warning", language, appConfig.currency), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.expenseColor)
                        .font(.subheadline)
                }
            }

            if let url = BankAlertShortcut.installURL(for: language) {
                Section {
                    QuickInstallCard(language: language) { UIApplication.shared.open(url) }
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                Toggle(isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) })) {
                    Text(t("bank_alert.settings.enable"))
                }
                .tint(AppTheme.primaryGreen)
            } footer: {
                Text(t(store.isEnabled ? "bank_alert.settings.enable_footer_on" : "bank_alert.settings.enable_footer_off"))
            }

            Section {
                NavigationLink {
                    BankAlertReviewView(store: store)
                } label: {
                    HStack {
                        Label(t("bank_alert.review.title"), systemImage: "tray.full.fill")
                        Spacer()
                        if !store.pending.isEmpty {
                            Text("\(store.pending.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppTheme.spacing8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.accentOrange))
                        }
                    }
                }
            }

            categorizationSection

            Section {
                ForEach(BankAlertChannel.allCases) { channel in
                    NavigationLink {
                        BankAlertGuideView(channel: channel)
                    } label: {
                        channelRow(channel)
                    }
                }
            } header: {
                Text(t("bank_alert.settings.guides_header"))
            } footer: {
                Text(t("bank_alert.settings.guides_footer"))
            }

            Section {
                HStack {
                    Text(BankInfo.vietcombank.name)
                    Spacer()
                    HStack(spacing: AppTheme.spacing4) {
                        ForEach(BankAlertChannel.allCases) { channel in
                            ChannelChip(channel: channel, support: channel.vietcombankSupport, language: language)
                        }
                    }
                }
            } header: {
                Text(t("bank_alert.settings.sources_header"))
            } footer: {
                VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                    HStack(spacing: AppTheme.spacing4) {
                        SupportBadge(support: .full, language: language)
                        Text(t("bank_alert.settings.legend_full"))
                    }
                    HStack(spacing: AppTheme.spacing4) {
                        SupportBadge(support: .beta, language: language)
                        Text(t("bank_alert.settings.legend_beta"))
                    }
                    Text(t("bank_alert.settings.other_banks_hint"))
                        .padding(.top, AppTheme.spacing4)
                }
            }

            Section {
                ForEach(store.templates) { template in
                    templateRow(template)
                }
                .onDelete { offsets in
                    offsets.map { store.templates[$0] }.forEach(store.deleteTemplate)
                }
                NavigationLink {
                    BankAlertTryView(store: store)
                } label: {
                    Label(t("bank_alert.templates.learn"), systemImage: "plus.circle")
                }
            } header: {
                Text(t("bank_alert.templates.header"))
            } footer: {
                Text(L10n.tr("bank_alert.templates.footer", language, BankAlertTemplate.trustThreshold))
            }

            if activeWallets.count > 1 {
                Section {
                    walletPicker(id: BankInfo.vietcombank.id, name: BankInfo.vietcombank.name)
                    ForEach(store.templates) { template in
                        walletPicker(id: template.id, name: template.bankName)
                    }
                } header: {
                    Text(t("bank_alert.settings.wallets_header"))
                } footer: {
                    Text(t("bank_alert.settings.wallets_footer"))
                }
            }

            Section {
                Toggle(isOn: Binding(get: { store.alwaysReview }, set: { store.setAlwaysReview($0) })) {
                    Text(t("bank_alert.settings.always_review"))
                }
                .tint(AppTheme.primaryGreen)
            } footer: {
                Text(t("bank_alert.settings.always_review_footer"))
            }

            Section {
                NavigationLink {
                    BankAlertTryView(store: store)
                } label: {
                    Label(t("bank_alert.try.title"), systemImage: "text.magnifyingglass")
                }
            } footer: {
                Label(t("bank_alert.settings.privacy"), systemImage: "lock.shield")
                    .padding(.top, AppTheme.spacing8)
            }
        }
        .navigationTitle(t("bank_alert.settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        .onAppear { store.reload() }
    }

    // MARK: - Categorization

    @ViewBuilder
    private var categorizationSection: some View {
        let uncategorizedCount = store.uncategorizedTransactions(transactions).count
        Section {
            if subscription.isPremium {
                Toggle(isOn: Binding(get: { store.useAI }, set: { store.setUseAI($0) })) {
                    Label(t("bank_alert.categorize.use_ai"), systemImage: "sparkles")
                }
                .tint(AppTheme.primaryGreen)
                NavigationLink {
                    BankAlertRulesView(store: store)
                } label: {
                    countRow(t("bank_alert.rules.title"), icon: "list.bullet.rectangle", count: store.rules.count, highlight: false)
                }
            } else {
                Button { showPaywall = true } label: { PremiumCategorizationPromo(language: language) }
                    .tint(.primary)
            }
            NavigationLink {
                BankAlertUncategorizedView(store: store)
            } label: {
                countRow(t("bank_alert.uncategorized.title"), icon: "questionmark.folder", count: uncategorizedCount, highlight: true)
            }
        } header: {
            Text(t("bank_alert.categorize.header"))
        } footer: {
            Text(t(subscription.isPremium ? "bank_alert.categorize.footer_premium" : "bank_alert.categorize.footer_free"))
        }
    }

    private func countRow(_ title: String, icon: String, count: Int, highlight: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(highlight ? .white : .secondary)
                    .padding(.horizontal, AppTheme.spacing8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(highlight ? AppTheme.accentOrange : Color.clear))
            }
        }
    }

    // MARK: - Rows

    private func channelRow(_ channel: BankAlertChannel) -> some View {
        let available = channel.isAvailable(onMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        return HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(iconName: channel.iconName, color: available ? AppTheme.accentTeal : .gray, size: 32, iconFont: .subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(t("bank_alert.channel.\(channel.rawValue)"))
                Text(available
                     ? t("bank_alert.channel.\(channel.rawValue)_subtitle")
                     : L10n.tr("bank_alert.channel.requires_ios", language, channel.minimumOSVersion))
                    .font(.caption)
                    .foregroundStyle(available ? Color.secondary : AppTheme.expenseColor)
            }
        }
    }

    private func templateRow(_ template: BankAlertTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(template.bankName)
                Spacer()
                SupportBadge(support: template.isTrusted ? .full : .beta, language: language)
            }
            Text(localizedPreview(template.preview))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(template.isTrusted
                 ? t("bank_alert.templates.trusted")
                 : L10n.tr("bank_alert.templates.learning", language, template.approvedCount, BankAlertTemplate.trustThreshold))
                .font(.caption)
                .foregroundStyle(template.isTrusted ? AppTheme.incomeColor : AppTheme.accentOrange)
        }
        .padding(.vertical, 2)
    }

    /// The stored preview uses fixed English placeholders; show them in the app language.
    private func localizedPreview(_ preview: String) -> String {
        preview
            .replacingOccurrences(of: "[±amount]", with: t("bank_alert.templates.placeholder_amount"))
            .replacingOccurrences(of: "[date]", with: t("bank_alert.templates.placeholder_date"))
            .replacingOccurrences(of: "[time]", with: t("bank_alert.templates.placeholder_time"))
    }

    private func walletPicker(id: String, name: String) -> some View {
        Picker(name, selection: Binding<String>(
            get: { store.walletIds[id] ?? "" },
            set: { store.setWalletId($0.isEmpty ? nil : $0, forBank: id) }
        )) {
            Text(t("bank_alert.settings.default_wallet")).tag("")
            ForEach(activeWallets) { wallet in
                Text(wallet.displayName(language: language)).tag(wallet.id)
            }
        }
    }
}

/// "Full" / "Beta" capsule used in the sources legend and template rows.
struct SupportBadge: View {
    let support: BankInfo.Support
    let language: String

    var body: some View {
        Text(L10n.tr(support == .full ? "bank_alert.support.full" : "bank_alert.support.beta", language))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(support == .full ? AppTheme.incomeColor : AppTheme.accentOrange))
    }
}

/// Channel icon tinted by how well that channel is supported.
private struct ChannelChip: View {
    let channel: BankAlertChannel
    let support: BankInfo.Support
    let language: String

    var body: some View {
        Image(systemName: channel.iconName)
            .font(.caption)
            .foregroundStyle(support == .full ? AppTheme.incomeColor : AppTheme.accentOrange)
            .frame(width: 24, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((support == .full ? AppTheme.incomeColor : AppTheme.accentOrange).opacity(0.15))
            )
            .accessibilityLabel(Text(
                L10n.tr("bank_alert.channel.\(channel.rawValue)", language) + ", " +
                L10n.tr(support == .full ? "bank_alert.support.full" : "bank_alert.support.beta", language)
            ))
    }
}

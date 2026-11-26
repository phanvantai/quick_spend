import SwiftUI

/// Step-by-step setup for one channel: the Shortcuts automation to create and
/// how to hand the alert text to "Add from Bank Alert". Steps follow the
/// device's iOS (27 moved automations into the shortcut editor). Vietnamese
/// gets screenshots of the iOS 27 editor.
struct BankAlertGuideView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(\.openURL) private var openURL

    let channel: BankAlertChannel
    /// Shown when the guide opens on its own (Home card, What's New), not from Settings.
    var showsAllSettingsLink = false

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }
    private var osMajor: Int { ProcessInfo.processInfo.operatingSystemVersion.majorVersion }
    private var guideKey: String { channel.guideKey(onMajorVersion: osMajor) }
    private var prefix: String { "bank_alert.guide.\(guideKey)" }

    /// Screenshots taken in Vietnamese, so shown for Vietnamese only.
    private var stepImages: [Int: String] {
        guard language == "vi", guideKey == "notification" else { return [:] }
        return [5: "bankalert_guide_vi_variable"]
    }

    private var finalImage: String? {
        language == "vi" && guideKey == "notification" ? "bankalert_guide_vi_complete" : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                HStack(spacing: AppTheme.spacing12) {
                    CategoryIconBadge(iconName: channel.iconName, color: AppTheme.accentTeal, size: 44, iconFont: .title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("bank_alert.channel.\(channel.rawValue)"))
                            .font(Typography.titleMedium)
                        Text(t("bank_alert.guide.\(channel.rawValue).intro"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !channel.isAvailable(onMajorVersion: osMajor) {
                    callout(
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.expenseColor,
                        text: L10n.tr("bank_alert.guide.requires_ios", language, channel.minimumOSVersion, osMajor)
                    )
                }

                if channel == .notification, let url = BankAlertShortcut.installURL(for: language) {
                    QuickInstallCard(language: language) { openURL(url) }
                }

                VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                    ForEach(1...channel.stepCount(onMajorVersion: osMajor), id: \.self) { step in
                        stepRow(number: step, text: t("\(prefix).step\(step)"))
                        if let image = stepImages[step] {
                            screenshot(image)
                        }
                    }
                }
                .padding(AppTheme.spacing16)
                .background(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).fill(Color(.secondarySystemGroupedBackground)))

                if let finalImage {
                    VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                        Text(t("bank_alert.guide.image_complete"))
                            .font(.subheadline.weight(.semibold))
                        screenshot(finalImage)
                    }
                }

                callout(icon: "lightbulb.fill", color: AppTheme.accentOrange, text: t("bank_alert.guide.\(channel.rawValue).tip"))
                callout(icon: "checkmark.seal.fill", color: AppTheme.incomeColor, text: t("bank_alert.guide.check"))

                if showsAllSettingsLink {
                    NavigationLink {
                        BankAlertSettingsView()
                    } label: {
                        Label(t("bank_alert.guide.all_settings"), systemImage: "gearshape")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.spacing8)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                } label: {
                    Label(t("bank_alert.guide.open_shortcuts"), systemImage: "square.2.layers.3d.fill")
                        .font(Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacing12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryGreen)
            }
            .padding(AppTheme.spacing16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(t("bank_alert.guide.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppTheme.primaryGreen))
            Text(markdown(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func screenshot(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 230)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).stroke(Color(.separator), lineWidth: 0.5))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private func callout(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacing8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(markdown(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).fill(color.opacity(0.12)))
    }

    /// Steps use **bold** for the names of buttons and menus.
    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

/// "Quick install": adds the ready-made shortcut, which brings its automation.
struct QuickInstallCard: View {
    let language: String
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Label(L10n.tr("bank_alert.quick_install.title", language), systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
            Text(L10n.tr("bank_alert.quick_install.subtitle", language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onInstall) {
                Text(L10n.tr("bank_alert.quick_install.button", language))
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primaryGreen)
        }
        .padding(AppTheme.spacing12)
        .background(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).fill(AppTheme.primaryGreen.opacity(0.12)))
    }
}

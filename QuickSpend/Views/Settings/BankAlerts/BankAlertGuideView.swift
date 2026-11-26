import SwiftUI

/// Step-by-step setup for one channel: which Shortcuts automation to create
/// and how to hand the alert text to "Add from Bank Alert".
struct BankAlertGuideView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(\.openURL) private var openURL

    let channel: BankAlertChannel

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }
    private var prefix: String { "bank_alert.guide.\(channel.rawValue)" }
    private var osMajor: Int { ProcessInfo.processInfo.operatingSystemVersion.majorVersion }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                HStack(spacing: AppTheme.spacing12) {
                    CategoryIconBadge(iconName: channel.iconName, color: AppTheme.accentTeal, size: 44, iconFont: .title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("bank_alert.channel.\(channel.rawValue)"))
                            .font(Typography.titleMedium)
                        Text(t("\(prefix).intro"))
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

                VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                    ForEach(1...channel.stepCount, id: \.self) { step in
                        stepRow(number: step, text: t("\(prefix).step\(step)"))
                    }
                }
                .padding(AppTheme.spacing16)
                .background(RoundedRectangle(cornerRadius: AppTheme.radiusMedium).fill(Color(.secondarySystemGroupedBackground)))

                callout(icon: "lightbulb.fill", color: AppTheme.accentOrange, text: t("\(prefix).tip"))
                callout(icon: "checkmark.seal.fill", color: AppTheme.incomeColor, text: t("bank_alert.guide.check"))

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

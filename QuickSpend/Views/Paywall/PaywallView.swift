import SwiftUI

/// Paywall screen showing subscription options
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription

    @State private var isPurchasing = false

    private var isVi: Bool { appConfig.language == "vi" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing24) {
                    heroSection
                    featuresSection
                    pricingSection
                    legalSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing32)
            }
            .navigationTitle("Quick Spend Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isVi ? "Đóng" : "Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isVi ? "Khôi phục" : "Restore") {
                        Task {
                            await subscription.restorePurchases()
                            if subscription.isPro { dismiss() }
                        }
                    }
                    .font(.caption)
                }
            }
            .overlay {
                if isPurchasing || subscription.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }

            Text(isVi ? "Mở khoá toàn bộ" : "Unlock Full Power")
                .font(.title2.bold())

            Text(isVi ? "Xoá giới hạn và tận dụng tối đa Quick Spend" : "Remove limits and get the most out of Quick Spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacing16)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            featureRow(
                icon: "mic.fill",
                color: AppTheme.primaryMint,
                title: isVi ? "Nhập giọng nói AI không giới hạn" : "Unlimited AI Voice Input",
                subtitle: isVi ? "Không giới hạn lượt phân tích AI mỗi ngày" : "No daily limit on AI-powered expense parsing"
            )
            featureRow(
                icon: "repeat",
                color: AppTheme.accentPink,
                title: isVi ? "Giao dịch định kỳ không giới hạn" : "Unlimited Recurring Templates",
                subtitle: isVi ? "Tạo bao nhiêu mẫu định kỳ tuỳ thích" : "Create as many recurring expenses as you need"
            )
            featureRow(
                icon: "chart.bar.fill",
                color: AppTheme.accentOrange,
                title: isVi ? "Báo cáo mở rộng" : "Extended Reports",
                subtitle: isVi ? "Xem báo cáo bất kỳ khoảng thời gian nào" : "View reports for any time range"
            )
            featureRow(
                icon: "heart.fill",
                color: AppTheme.error,
                title: isVi ? "Hỗ trợ phát triển" : "Support Development",
                subtitle: isVi ? "Giúp chúng tôi xây dựng tính năng tốt hơn" : "Help us build better features for you"
            )
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: AppTheme.spacing12) {
            // Yearly (best value)
            Button {
                purchase(yearly: true)
            } label: {
                VStack(spacing: AppTheme.spacing4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(isVi ? "Hàng năm" : "Yearly")
                                .font(.headline)
                            Text("$\(String(format: "%.2f", AppConstants.subscriptionYearlyPriceUSD))/\(isVi ? "năm" : "year")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(isVi ? "Tiết kiệm nhất" : "Best Value")
                            .font(.caption.bold())
                            .padding(.horizontal, AppTheme.spacing8)
                            .padding(.vertical, AppTheme.spacing4)
                            .background {
                                Capsule()
                                    .fill(AppTheme.primaryMint.opacity(0.2))
                            }
                            .foregroundStyle(AppTheme.primaryMint)
                    }
                }
                .padding(AppTheme.spacing16)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(AppTheme.primaryMint, lineWidth: 2)
                }
            }
            .tint(.primary)

            // Monthly
            Button {
                purchase(yearly: false)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(isVi ? "Hàng tháng" : "Monthly")
                            .font(.headline)
                        Text("$\(String(format: "%.2f", AppConstants.subscriptionMonthlyPriceUSD))/\(isVi ? "tháng" : "month")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(AppTheme.spacing16)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
            .tint(.primary)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: AppTheme.spacing4) {
            Text(isVi
                 ? "Đăng ký tự động gia hạn trừ khi huỷ ít nhất 24 giờ trước khi kết thúc kỳ hiện tại."
                 : "Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.spacing16) {
                if let termsURL = URL(string: AppConstants.termsOfUseUrl) {
                    Link(isVi ? "Điều khoản sử dụng" : "Terms of Use", destination: termsURL)
                        .font(.caption2)
                }
                if let privacyURL = URL(string: AppConstants.privacyPolicyUrl) {
                    Link(isVi ? "Chính sách bảo mật" : "Privacy Policy", destination: privacyURL)
                        .font(.caption2)
                }
            }
        }
        .padding(.top, AppTheme.spacing8)
    }

    // MARK: - Actions

    private func purchase(yearly: Bool) {
        isPurchasing = true
        Task {
            let success = yearly
                ? await subscription.purchaseYearly()
                : await subscription.purchaseMonthly()
            isPurchasing = false
            if success { dismiss() }
        }
    }
}

#Preview {
    PaywallView()
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}

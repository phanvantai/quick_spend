import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/subscription_provider.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';

/// Paywall screen showing subscription pricing and features
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isYearly = true; // Default to yearly (better value)
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('subscription.upgrade_to_premium')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacing24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.tr('subscription.unlock_features'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    context.tr('subscription.get_unlimited'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Pricing toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPricingOption(
                        label: context.tr('subscription.monthly'),
                        price: '\$${AppConstants.subscriptionMonthlyPriceUSD}${context.tr('subscription.per_month')}',
                        isSelected: !_isYearly,
                        onTap: () => setState(() => _isYearly = false),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildPricingOption(
                            label: context.tr('subscription.yearly'),
                            price: '\$${(AppConstants.subscriptionYearlyPriceUSD / 12).toStringAsFixed(2)}${context.tr('subscription.per_month')}',
                            isSelected: _isYearly,
                            onTap: () => setState(() => _isYearly = true),
                          ),
                          Positioned(
                            top: -8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.tr('subscription.save_percent', namedArgs: {'percent': '30'}),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing32),

            // Features comparison
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('subscription.premium_features'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildFeatureItem(
                    icon: Icons.auto_awesome,
                    title: context.tr('subscription.feature_unlimited_ai'),
                    subtitle: context.tr('subscription.feature_unlimited_ai_subtitle', namedArgs: {'free': '5'}),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.mic,
                    title: context.tr('subscription.feature_unlimited_voice'),
                    subtitle: context.tr('subscription.feature_unlimited_voice_subtitle'),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.repeat,
                    title: context.tr('subscription.feature_unlimited_recurring'),
                    subtitle: context.tr('subscription.feature_unlimited_recurring_subtitle', namedArgs: {'free': '3'}),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.analytics,
                    title: context.tr('subscription.feature_advanced_reports'),
                    subtitle: context.tr('subscription.feature_advanced_reports_subtitle', namedArgs: {'free': '7'}),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.category,
                    title: context.tr('subscription.feature_custom_categories'),
                    subtitle: context.tr('subscription.feature_custom_categories_subtitle'),
                    isPremium: false,
                  ),
                  _buildFeatureItem(
                    icon: Icons.import_export,
                    title: context.tr('subscription.feature_import_export'),
                    subtitle: context.tr('subscription.feature_import_export_subtitle'),
                    isPremium: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing32),

            // Purchase button
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.tr(
                                'subscription.start_for_price',
                                namedArgs: {
                                  'price': _isYearly
                                      ? '\$${AppConstants.subscriptionYearlyPriceUSD}${context.tr('subscription.per_year')}'
                                      : '\$${AppConstants.subscriptionMonthlyPriceUSD}${context.tr('subscription.per_month')}',
                                },
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    _isYearly
                        ? context.tr('subscription.billed_yearly', namedArgs: {'amount': '\$${AppConstants.subscriptionYearlyPriceUSD}'})
                        : context.tr('subscription.billed_monthly'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    context.tr('subscription.mock_payment_notice'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingOption({
    required String label,
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPremium,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPremium
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isPremium ? AppTheme.primaryColor : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('subscription.pro_badge'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Mock upgrade to premium
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final expiryDate = _isYearly
          ? DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 30));

      await subscriptionProvider.upgradeToPremium(
        expiryDate: expiryDate,
        platform: 'mock',
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('subscription.welcome_to_premium')),
            backgroundColor: AppTheme.success,
          ),
        );

        // Go back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/subscription_provider.dart';
import '../services/revenue_cat_service.dart';
import '../services/subscription_service.dart';
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
  bool _isLoading = true;
  bool _isRestoring = false;

  // RevenueCat products
  Offering? _currentOffering;
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  /// Load subscription products from RevenueCat
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await RevenueCatService.instance.getOfferings();

      if (!mounted) return;

      if (offerings == null || offerings.current == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No subscription products available';
        });
        return;
      }

      _currentOffering = offerings.current;

      // Find monthly and yearly packages
      // RevenueCat standard identifiers: $rc_monthly, $rc_annual
      for (final package in _currentOffering!.availablePackages) {
        if (package.identifier == '\$rc_monthly') {
          _monthlyPackage = package;
        } else if (package.identifier == '\$rc_annual') {
          _yearlyPackage = package;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load products: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('subscription.upgrade_to_premium')),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacing24),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
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
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Pricing toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
              ),
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
                        price: _monthlyPackage?.storeProduct.priceString ??
                            '\$${AppConstants.subscriptionMonthlyPriceUSD}${context.tr('subscription.per_month')}',
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
                            price: _getYearlyPricePerMonth(),
                            isSelected: _isYearly,
                            onTap: () => setState(() => _isYearly = true),
                          ),
                          Positioned(
                            top: -12,
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
                                context.tr(
                                  'subscription.save_percent',
                                  namedArgs: {'percent': '30'},
                                ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
              ),
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
                    subtitle: context.tr(
                      'subscription.feature_unlimited_ai_subtitle',
                      namedArgs: {'free': '5'},
                    ),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.mic,
                    title: context.tr('subscription.feature_unlimited_voice'),
                    subtitle: context.tr(
                      'subscription.feature_unlimited_voice_subtitle',
                    ),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.repeat,
                    title: context.tr(
                      'subscription.feature_unlimited_recurring',
                    ),
                    subtitle: context.tr(
                      'subscription.feature_unlimited_recurring_subtitle',
                      namedArgs: {'free': '3'},
                    ),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.analytics,
                    title: context.tr('subscription.feature_advanced_reports'),
                    subtitle: context.tr(
                      'subscription.feature_advanced_reports_subtitle',
                    ),
                    isPremium: true,
                  ),
                  _buildFeatureItem(
                    icon: Icons.category,
                    title: context.tr('subscription.feature_custom_categories'),
                    subtitle: context.tr(
                      'subscription.feature_custom_categories_subtitle',
                    ),
                    isPremium: false,
                  ),
                  _buildFeatureItem(
                    icon: Icons.import_export,
                    title: context.tr('subscription.feature_import_export'),
                    subtitle: context.tr(
                      'subscription.feature_import_export_subtitle',
                    ),
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
                        backgroundColor: AppTheme.primaryDark,
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
                                  'price': _getCurrentPrice(),
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
                        ? context.tr(
                            'subscription.billed_yearly',
                            namedArgs: {
                              'amount': _yearlyPackage?.storeProduct.priceString ??
                                  '\$${AppConstants.subscriptionYearlyPriceUSD}',
                            },
                          )
                        : context.tr('subscription.billed_monthly'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  // Restore purchases button
                  TextButton(
                    onPressed: _isRestoring ? null : _handleRestore,
                    child: _isRestoring
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('subscription.restore_purchases')),
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
        width: double.maxFinite,
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
                    color: Colors.black.withValues(alpha: 0.1),
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
                color: isSelected ? AppTheme.primaryDark : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? AppTheme.primaryDark : Colors.grey[600],
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
                  ? AppTheme.primaryDark.withValues(alpha: 0.1)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isPremium ? AppTheme.primaryDark : Colors.grey[600],
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
                          color: AppTheme.primaryDark,
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
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    final package = _isYearly ? _yearlyPackage : _monthlyPackage;

    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('subscription.price_unavailable')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Purchase via RevenueCat
      await RevenueCatService.instance.purchasePackage(package);

      if (!mounted) return;

      // Sync subscription status from RevenueCat
      await SubscriptionService.syncFromRevenueCat();

      // Update subscription provider
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.refreshSubscriptionStatus();

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
    } on PlatformException catch (e) {
      if (!mounted) return;

      // Handle purchase cancellation gracefully
      if (e.code == PurchasesErrorCode.purchaseCancelledError.toString()) {
        // User cancelled, no error needed
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('subscription.purchase_error', namedArgs: {'error': e.message ?? 'Unknown error'})),
          backgroundColor: AppTheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('subscription.purchase_failed')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);

    try {
      await RevenueCatService.instance.restorePurchases();

      if (!mounted) return;

      // Sync subscription status from RevenueCat
      await SubscriptionService.syncFromRevenueCat();

      // Update subscription provider
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.refreshSubscriptionStatus();

      if (mounted) {
        final isPremium = await SubscriptionService.isPremium();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPremium
                  ? context.tr('subscription.restore_success')
                  : context.tr('subscription.restore_no_purchases'),
            ),
            backgroundColor: isPremium ? AppTheme.success : Colors.orange,
          ),
        );

        if (isPremium) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('subscription.restore_failed', namedArgs: {'error': e.toString()})),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  /// Get yearly price divided by 12 for monthly comparison
  String _getYearlyPricePerMonth() {
    if (_yearlyPackage == null) {
      return '\$${(AppConstants.subscriptionYearlyPriceUSD / 12).toStringAsFixed(2)}${context.tr('subscription.per_month')}';
    }

    // For now, just show the full yearly price
    // TODO: Calculate monthly equivalent if needed
    return _yearlyPackage!.storeProduct.priceString;
  }

  /// Get current selected package price
  String _getCurrentPrice() {
    if (_isYearly) {
      return _yearlyPackage?.storeProduct.priceString ??
          '\$${AppConstants.subscriptionYearlyPriceUSD}${context.tr('subscription.per_year')}';
    } else {
      return _monthlyPackage?.storeProduct.priceString ??
          '\$${AppConstants.subscriptionMonthlyPriceUSD}${context.tr('subscription.per_month')}';
    }
  }

  /// Build error state widget
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.tr('subscription.loading_failed'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing24),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('subscription.loading_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

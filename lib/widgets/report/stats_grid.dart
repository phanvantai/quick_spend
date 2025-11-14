import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/app_config.dart';
import '../../models/period_stats.dart';
import '../../theme/app_theme.dart';

/// Grid of statistic cards showing various metrics
class StatsGrid extends StatelessWidget {
  final PeriodStats stats;
  final AppConfig appConfig;

  const StatsGrid({
    super.key,
    required this.stats,
    required this.appConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // First row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.calendar_today,
                iconColor: AppTheme.accentTeal,
                value: _formatAmount(context, stats.averagePerDay),
                label: context.tr('report.avg_per_day'),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.trending_up,
                iconColor: AppTheme.error,
                value: stats.highestExpense != null
                    ? _formatAmount(context, stats.highestExpense!.amount)
                    : _formatAmount(context, 0),
                label: context.tr('report.highest_expense'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing12),
        // Second row - Income statistics
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.account_balance_wallet,
                iconColor: AppTheme.success,
                value: stats.highestIncome != null
                    ? _formatAmount(context, stats.highestIncome!.amount)
                    : _formatAmount(context, 0),
                label: context.tr('report.highest_income'),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.show_chart,
                iconColor: AppTheme.accentOrange,
                value: '${stats.incomeCount} / ${stats.expenseCount}',
                label: context.tr('report.income_expense_count'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(BuildContext context, double amount) {
    String formatted;
    final currency = appConfig.currency;
    final language = appConfig.language;

    // Determine if currency uses decimals
    // VND, JPY, KRW: no decimals
    // USD, THB, EUR: 2 decimals
    final useDecimals = currency != 'VND' && currency != 'JPY' && currency != 'KRW';
    final pattern = useDecimals ? '#,##0.00' : '#,##0';

    // Format based on language: use appropriate thousand/decimal separators
    // vi and es: period for thousands, comma for decimal
    // en, ja, ko, th: comma for thousands, period for decimal
    if (language == 'vi' || language == 'es') {
      // Vietnamese and Spanish format: period as thousand separator, comma as decimal
      final formatter = NumberFormat(pattern, 'en_US');
      formatted = formatter.format(amount).replaceAll(',', '.');
    } else {
      // English, Japanese, Korean, Thai format: comma as thousand separator, period as decimal
      final formatter = NumberFormat(pattern, 'en_US');
      formatted = formatter.format(amount);
    }

    // Add currency symbol
    final currencySymbol = appConfig.currencySymbol;

    // Most currencies: symbol before amount
    return '$currencySymbol$formatted';
  }
}

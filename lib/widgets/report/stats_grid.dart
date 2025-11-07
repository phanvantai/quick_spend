import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/period_stats.dart';
import '../../theme/app_theme.dart';

/// Grid of statistic cards showing various metrics
class StatsGrid extends StatelessWidget {
  final PeriodStats stats;
  final String currency;
  final String language;

  const StatsGrid({
    super.key,
    required this.stats,
    required this.currency,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.calendar_today,
            iconColor: Colors.blue,
            value: _formatAmount(context, stats.averagePerDay),
            label: context.tr('report.avg_per_day'),
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.trending_up,
            iconColor: Colors.red,
            value: stats.highestExpense != null
                ? _formatAmount(context, stats.highestExpense!.amount)
                : _formatAmount(context, 0),
            label: context.tr('report.highest_expense'),
          ),
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
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
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
    if (language == 'vi') {
      // Vietnamese format
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return currency == 'VND'
          ? '$formatted${context.tr('currency.symbol_vnd')}'
          : '${context.tr('currency.symbol_usd')}$formatted';
    } else {
      // English format
      final formatted = amount.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return currency == 'USD'
          ? '${context.tr('currency.symbol_usd')}$formatted'
          : '$formatted ${context.tr('currency.symbol_vnd')}';
    }
  }
}

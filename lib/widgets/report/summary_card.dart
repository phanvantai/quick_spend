import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/period_stats.dart';
import '../../theme/app_theme.dart';

/// Summary statistics card showing total spending and trends
class SummaryCard extends StatelessWidget {
  final PeriodStats stats;
  final double? trendPercentage;
  final bool isTrendPositive;
  final String currency;
  final String language;

  const SummaryCard({
    super.key,
    required this.stats,
    this.trendPercentage,
    required this.isTrendPositive,
    required this.currency,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.borderRadiusMedium,
        ),
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              context.tr('report.total_spending'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),

            // Total amount with trend
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _formatAmount(context, stats.totalAmount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 36,
                    ),
                  ),
                ),
                if (trendPercentage != null) _buildTrendIndicator(theme),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Statistics row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.receipt_long,
                    stats.transactionCount.toString(),
                    stats.transactionCount == 1
                        ? context.tr('report.expense')
                        : context.tr('report.expenses'),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.trending_up,
                    _formatAmount(context, stats.averagePerTransaction),
                    context.tr('report.avg_per_transaction'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(ThemeData theme) {
    final isPositive = isTrendPositive;
    final percentage = trendPercentage!.abs();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppTheme.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: AppTheme.spacing4),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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

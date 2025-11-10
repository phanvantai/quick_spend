import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/category_stats.dart';
import '../../theme/app_theme.dart';

/// List view showing category breakdown with progress bars
class CategoryList extends StatelessWidget {
  final List<CategoryStats> categoryStats;
  final String currency;
  final String language;
  final Function(CategoryStats)? onCategoryTap;

  const CategoryList({
    super.key,
    required this.categoryStats,
    required this.currency,
    required this.language,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context);

    if (categoryStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.only(
        //     left: AppTheme.spacing4,
        //     bottom: AppTheme.spacing12,
        //   ),
        //   child: Text(
        //     context.tr('report.spending_by_category'),
        //     style: theme.textTheme.titleMedium?.copyWith(
        //       fontWeight: FontWeight.w600,
        //     ),
        //   ),
        // ),
        ...categoryStats.map((stat) => _buildCategoryItem(context, stat)),
      ],
    );
  }

  Widget _buildCategoryItem(BuildContext context, CategoryStats stat) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onCategoryTap != null ? () => onCategoryTap!(stat) : null,
      borderRadius: AppTheme.borderRadiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacing12,
          horizontal: AppTheme.spacing4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header with icon, name, and amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: stat.color.withValues(alpha: 0.15),
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  child: Icon(stat.icon, size: 20, color: stat.color),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.getLabel(language),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${stat.count} ${stat.count == 1 ? context.tr('report.transaction') : context.tr('report.transactions')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(context, stat.totalAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: stat.color,
                      ),
                    ),
                    Text(
                      '${stat.percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
            // Progress bar
            ClipRRect(
              borderRadius: AppTheme.borderRadiusSmall,
              child: LinearProgressIndicator(
                value: stat.percentage / 100,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(stat.color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(BuildContext context, double amount) {
    if (language == 'vi') {
      // Vietnamese format
      final formatted = amount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return currency == 'VND'
          ? '$formatted${context.tr('currency.symbol_vnd')}'
          : '${context.tr('currency.symbol_usd')}$formatted';
    } else {
      // English format
      final formatted = amount
          .toStringAsFixed(2)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return currency == 'USD'
          ? '${context.tr('currency.symbol_usd')}$formatted'
          : '$formatted ${context.tr('currency.symbol_vnd')}';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../models/expense.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_theme.dart';

/// Card widget for displaying expense information
class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categoryData =
        categoryProvider.getCategoryById(expense.categoryId) ??
        categoryProvider.getCategoryById('other') ??
        QuickCategory.getDefaultSystemCategories().firstWhere(
          (c) => c.id == 'other',
        ); // Fallback to system 'other' category
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on transaction type
    final isIncome = expense.isIncome;
    final accentColor = isIncome ? AppTheme.success : AppTheme.error;
    final amountPrefix = isIncome ? '+' : '-';

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: accentColor,
              width: 4,
            ),
          ),
          borderRadius: AppTheme.borderRadiusMedium,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppTheme.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: categoryData.color.withValues(alpha: 0.15),
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  child: Icon(
                    categoryData.icon,
                    color: categoryData.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),

                // Expense details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            categoryData.getLabel(expense.language),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: categoryData.color,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Flexible(
                            child: Text(
                              _formatDate(context, expense.date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix${expense.getFormattedAmount()}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    if (expense.confidence < 0.8) ...[
                      const SizedBox(height: AppTheme.spacing4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: AppTheme.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Text(
                          'Low confidence',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    // Get current locale from context
    final locale = context.locale.languageCode;

    if (dateOnly == today) {
      return context.tr('common.today');
    } else if (dateOnly == yesterday) {
      return context.tr('common.yesterday');
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.E(locale).format(date); // Day of week
    } else {
      return DateFormat.MMMd(locale).format(date); // Month and day
    }
  }
}

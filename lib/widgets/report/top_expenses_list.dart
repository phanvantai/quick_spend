import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_theme.dart';

/// List showing top expenses for the selected period
class TopExpensesList extends StatelessWidget {
  final List<Expense> expenses;
  final String currency;
  final String language;
  final Function(Expense)? onExpenseTap;
  final int limit;

  const TopExpensesList({
    super.key,
    required this.expenses,
    required this.currency,
    required this.language,
    this.onExpenseTap,
    this.limit = 5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final topExpenses = expenses.take(limit).toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacing4,
                bottom: AppTheme.spacing12,
              ),
              child: Row(
                children: [
                  Text(
                    'report.top_expenses'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: Text(
                      topExpenses.length.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...topExpenses.asMap().entries.map((entry) {
              final index = entry.key;
              final expense = entry.value;
              return _buildExpenseItem(
                context,
                expense,
                index + 1,
                index == topExpenses.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseItem(
    BuildContext context,
    Expense expense,
    int rank,
    bool isLast,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryProvider = context.watch<CategoryProvider>();
    final categoryData =
        categoryProvider.getCategoryById(expense.categoryId) ??
        categoryProvider.getCategoryById('other') ??
        QuickCategory.getDefaultSystemCategories().firstWhere(
          (c) => c.id == 'other',
        ); // Fallback to system 'other' category

    return InkWell(
      onTap: onExpenseTap != null ? () => onExpenseTap!(expense) : null,
      borderRadius: AppTheme.borderRadiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacing12,
          horizontal: AppTheme.spacing4,
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: rank <= 3 ? AppTheme.primaryGradient : null,
                color: rank > 3 ? colorScheme.surfaceContainerHighest : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: rank <= 3
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),

            // Category icon
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: categoryData.color.withValues(alpha: 0.15),
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              child: Icon(
                categoryData.icon,
                size: 20,
                color: categoryData.color,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),

            // Expense details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      Text(
                        categoryData.getLabel(language),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
                          DateFormat('MMM d, y', context.locale.languageCode).format(expense.date),
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
            const SizedBox(width: AppTheme.spacing12),

            // Amount
            Text(
              _formatAmount(expense.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: categoryData.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    String formatted;

    // Use decimals based on currency, not language
    final useDecimals = currency != 'VND';

    if (language == 'vi') {
      // Vietnamese format: use period as thousand separator
      final formatter = NumberFormat(useDecimals ? '#,##0.00' : '#,##0', 'en_US');
      formatted = formatter.format(amount).replaceAll(',', '.');
      return currency == 'VND' ? '$formatted đ' : '\$$formatted';
    } else {
      // English format: use comma as thousand separator
      final formatter = NumberFormat(useDecimals ? '#,##0.00' : '#,##0', 'en_US');
      formatted = formatter.format(amount);
      return currency == 'USD' ? '\$$formatted' : '$formatted đ';
    }
  }
}

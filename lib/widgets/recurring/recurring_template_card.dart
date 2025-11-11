import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:quick_spend/models/expense.dart';
import '../../models/recurring_expense_template.dart';
import '../../providers/category_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../theme/app_theme.dart';

/// Card widget for displaying a recurring expense template
class RecurringTemplateCard extends StatelessWidget {
  final RecurringExpenseTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleActive;

  const RecurringTemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final appConfig = context.watch<AppConfigProvider>().config;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find the category for this template
    final category = categoryProvider.categories
        .where((c) => c.id == template.categoryId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: category != null
                    ? category.color.withValues(alpha: 0.15)
                    : AppTheme.neutral500.withValues(alpha: 0.15),
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: category?.color ?? AppTheme.neutral500,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    template.description,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!template.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.neutral500.withValues(alpha: 0.15),
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: Text(
                      context.tr('recurring.inactive'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  template.getFormattedAmount(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: template.type == TransactionType.expense
                        ? AppTheme.error
                        : AppTheme.success,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      template.pattern.getDescription(appConfig.language),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (template.endDate != null) ...[
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        '•',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Icon(
                        Icons.event,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        context.tr(
                          'recurring.until',
                          namedArgs: {
                            'date': DateFormat.yMMMd(
                              appConfig.language,
                            ).format(template.endDate!),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 20),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(context.tr('common.edit')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 20),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(context.tr('common.delete')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Icon(
                  template.isActive ? Icons.check_circle : Icons.pause_circle,
                  size: 16,
                  color: template.isActive
                      ? AppTheme.success
                      : AppTheme.neutral500,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  template.isActive
                      ? context.tr('recurring.active')
                      : context.tr('recurring.paused'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: template.isActive
                        ? AppTheme.success
                        : AppTheme.neutral500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: template.isActive,
                  onChanged: onToggleActive,
                  activeThumbColor: AppTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

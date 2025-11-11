import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/recurring_template_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/recurring/recurring_template_card.dart';
import '../widgets/common/empty_state.dart';
import '../theme/app_theme.dart';
import 'recurring_expense_form_screen.dart';

/// Screen for managing recurring expense templates
class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  void _showAddScreen(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecurringExpenseFormScreen(userId: userId),
      ),
    );
  }

  void _showEditScreen(BuildContext context, String templateId, String userId) {
    final templateProvider = context.read<RecurringTemplateProvider>();
    final template = templateProvider.getTemplateById(templateId);

    if (template != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RecurringExpenseFormScreen(template: template, userId: userId),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String templateId,
    String description,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('recurring.delete_confirm_title')),
        content: Text(
          context.tr(
            'recurring.delete_confirm_message',
            namedArgs: {'name': description},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            label: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<RecurringTemplateProvider>().deleteTemplate(
          templateId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('recurring.template_deleted')),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ [RecurringExpensesScreen] Error deleting template: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'recurring.error_deleting',
                  namedArgs: {'error': e.toString()},
                ),
              ),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    String templateId,
    bool isActive,
  ) async {
    try {
      await context.read<RecurringTemplateProvider>().toggleActive(
        templateId,
        isActive,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? context.tr('recurring.template_activated')
                  : context.tr('recurring.template_deactivated'),
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [RecurringExpensesScreen] Error toggling active: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'recurring.error_toggling',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer2<RecurringTemplateProvider, ExpenseProvider>(
      builder: (context, templateProvider, expenseProvider, _) {
        final userId = expenseProvider.currentUserId;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(context.tr('recurring.title')),
            actions: [
              if (templateProvider.templates.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: context.tr('recurring.info'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            const Icon(Icons.info, color: AppTheme.info),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(child: Text(context.tr('recurring.info'))),
                          ],
                        ),
                        content: Text(context.tr('recurring.info_message')),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.tr('common.ok')),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: templateProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : templateProvider.templates.isEmpty
              ? EmptyState(
                  icon: Icons.repeat,
                  title: context.tr('recurring.empty_title'),
                  message: context.tr('recurring.empty_message'),
                )
              : RefreshIndicator(
                  onRefresh: () => templateProvider.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppTheme.spacing8,
                      bottom: AppTheme.spacing64,
                    ),
                    itemCount: templateProvider.templates.length,
                    itemBuilder: (context, index) {
                      final template = templateProvider.templates[index];
                      return RecurringTemplateCard(
                        template: template,
                        onEdit: () =>
                            _showEditScreen(context, template.id, userId),
                        onDelete: () => _showDeleteConfirmation(
                          context,
                          template.id,
                          template.description,
                        ),
                        onToggleActive: (isActive) =>
                            _toggleActive(context, template.id, isActive),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddScreen(context, userId),
            icon: const Icon(Icons.add),
            label: Text(context.tr('recurring.add_template')),
          ),
        );
      },
    );
  }
}

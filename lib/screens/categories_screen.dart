import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';
import 'category_form_screen.dart';

/// Screen for managing expense categories
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(context.tr('settings.categories')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddCategory(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('categories.add_category')),
        backgroundColor: AppTheme.primaryMint,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<CategoryProvider, AppConfigProvider>(
        builder: (context, categoryProvider, appConfigProvider, _) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final language = appConfigProvider.language;
          final systemCategories = categoryProvider.systemCategories;
          final userCategories = categoryProvider.userCategories;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88), // Space for FAB
            children: [
              // System Categories Section
              _buildSectionHeader(
                context,
                context.tr('categories.system_categories'),
                context.tr('categories.system_categories_subtitle'),
              ),
              ...systemCategories.map((category) {
                return _buildCategoryTile(
                  context,
                  category,
                  language,
                  isSystem: true,
                );
              }),

              const SizedBox(height: AppTheme.spacing24),

              // User Categories Section
              _buildSectionHeader(
                context,
                context.tr('categories.user_categories'),
                context.tr('categories.user_categories_subtitle'),
              ),
              if (userCategories.isEmpty)
                _buildEmptyState(context)
              else
                ...userCategories.map((category) {
                  return _buildCategoryTile(
                    context,
                    category,
                    language,
                    isSystem: false,
                    onDelete: () => _deleteCategory(context, category),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    QuickCategory category,
    String language, {
    required bool isSystem,
    VoidCallback? onDelete,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(
            category.icon,
            color: category.color,
            size: 24,
          ),
        ),
        title: Text(
          category.getLabel(language),
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          isSystem
              ? context.tr('categories.system_category')
              : _formatKeywords(category.getKeywords(language)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isSystem
            ? Icon(
                Icons.lock_outline,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              )
            : IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                ),
                onPressed: onDelete,
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.tr('categories.no_user_categories'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.tr('categories.tap_add_to_create'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatKeywords(List<String> keywords) {
    if (keywords.isEmpty) return '';
    return keywords.take(3).join(', ') + (keywords.length > 3 ? '...' : '');
  }

  Future<void> _navigateToAddCategory(BuildContext context) async {
    final result = await Navigator.push<QuickCategory>(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryFormScreen(),
      ),
    );

    if (result != null && context.mounted) {
      final categoryProvider = context.read<CategoryProvider>();
      try {
        await categoryProvider.createCategory(result);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('categories.category_added')),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'categories.error_adding_category',
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

  Future<void> _deleteCategory(
    BuildContext context,
    QuickCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('categories.delete_category')),
        content: Text(
          context.tr(
            'categories.delete_category_confirm',
            namedArgs: {'name': category.getLabel('en')},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final categoryProvider = context.read<CategoryProvider>();
      try {
        await categoryProvider.deleteCategory(category.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('categories.category_deleted')),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'categories.error_deleting_category',
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
}

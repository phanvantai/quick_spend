import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_config.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../theme/app_theme.dart';
import 'categories_screen.dart';

/// Settings screen for changing app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AppConfigProvider>(
      builder: (context, configProvider, _) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(title: Text(context.tr('settings.title'))),
          body: configProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // Preferences Section
                    _buildSectionHeader(context.tr('settings.preferences')),

                    _buildListTile(
                      icon: Icons.category_outlined,
                      iconColor: AppTheme.accentTeal,
                      title: context.tr('settings.categories'),
                      subtitle: context.tr('settings.manage_categories'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesScreen(),
                          ),
                        );
                      },
                    ),

                    _buildListTile(
                      icon: Icons.language,
                      iconColor: AppTheme.primaryMint,
                      title: context.tr('settings.language'),
                      subtitle: _getLanguageDisplayName(
                        configProvider.language,
                      ),
                      onTap: () => _showLanguageDialog(context),
                    ),

                    _buildListTile(
                      icon: Icons.attach_money,
                      iconColor: AppTheme.accentOrange,
                      title: context.tr('settings.currency'),
                      subtitle: _getCurrencyDisplayName(
                        configProvider.currency,
                      ),
                      onTap: () => _showCurrencyDialog(context),
                    ),

                    _buildListTile(
                      icon: Icons.palette_outlined,
                      iconColor: AppTheme.accentPink,
                      title: context.tr('settings.theme'),
                      subtitle: _getThemeDisplayName(configProvider.themeMode),
                      onTap: () => _showThemeDialog(context),
                    ),

                    const Divider(height: 32),

                    // Data Section
                    _buildSectionHeader(context.tr('settings.data')),

                    _buildListTile(
                      icon: Icons.upload_file,
                      iconColor: AppTheme.success,
                      title: context.tr('settings.export_data'),
                      subtitle: context.tr('settings.export_data_subtitle'),
                      onTap: () => _showExportDialog(context),
                    ),

                    _buildListTile(
                      icon: Icons.download,
                      iconColor: AppTheme.info,
                      title: context.tr('settings.import_data'),
                      subtitle: context.tr('settings.import_data_subtitle'),
                      onTap: () => _handleImport(context),
                    ),

                    const Divider(height: 32),

                    // About Section
                    _buildSectionHeader(context.tr('settings.about')),

                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.wallet_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('app.name'),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing4),
                                  Text(
                                    context.tr('settings.version'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing8),
                                  Text(
                                    context.tr('app.tagline'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppTheme.spacing8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        onTap: onTap,
      ),
    );
  }

  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'vi':
        return context.tr('settings.language_vi');
      case 'en':
      default:
        return context.tr('settings.language_en');
    }
  }

  String _getCurrencyDisplayName(String currencyCode) {
    switch (currencyCode) {
      case 'VND':
        return context.tr('settings.currency_vnd_display');
      case 'USD':
      default:
        return context.tr('settings.currency_usd_display');
    }
  }

  String _getThemeDisplayName(String themeMode) {
    switch (themeMode) {
      case 'light':
        return context.tr('settings.theme_light');
      case 'dark':
        return context.tr('settings.theme_dark');
      case 'system':
      default:
        return context.tr('settings.theme_system');
    }
  }

  // Language Selection Dialog
  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer<AppConfigProvider>(
        builder: (ctx, configProvider, _) => AlertDialog(
          title: Text(ctx.tr('settings.language')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LanguageOption.options.map((option) {
              final isSelected = configProvider.language == option.code;
              return _buildDialogOption(
                leading: Text(
                  option.flag,
                  style: const TextStyle(fontSize: 28),
                ),
                title: option.displayName,
                isSelected: isSelected,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _changeLanguage(context, option.code, option.countryCode);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Currency Selection Dialog
  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer<AppConfigProvider>(
        builder: (ctx, configProvider, _) => AlertDialog(
          title: Text(ctx.tr('settings.currency')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: CurrencyOption.options.map((option) {
              final isSelected = configProvider.currency == option.code;
              return _buildDialogOption(
                leading: Text(
                  option.symbol,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: ctx.tr(option.displayNameKey),
                subtitle: option.code,
                isSelected: isSelected,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _changeCurrency(context, option.code);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Theme Selection Dialog
  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Consumer<AppConfigProvider>(
        builder: (ctx, configProvider, _) {
          final colorScheme = Theme.of(ctx).colorScheme;

          return AlertDialog(
            title: Text(ctx.tr('settings.theme')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeModeOption.options.map((option) {
                final isSelected = configProvider.themeMode == option.code;
                return _buildDialogOption(
                  leading: Icon(
                    option.icon,
                    size: 28,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: ctx.tr(option.displayNameKey),
                  isSelected: isSelected,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _changeThemeMode(context, option.code);
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogOption({
    required Widget leading,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: AppTheme.borderRadiusSmall,
        ),
        child: Row(
          children: [
            SizedBox(width: 48, child: Center(child: leading)),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(
    BuildContext context,
    String languageCode,
    String countryCode,
  ) async {
    final configProvider = context.read<AppConfigProvider>();
    if (configProvider.language == languageCode) return;

    final messenger = ScaffoldMessenger.of(context);
    final locale = Locale(languageCode, countryCode);

    try {
      // First set the locale
      await context.setLocale(locale);

      // Then update the provider (which will trigger rebuild)
      await configProvider.setLanguage(languageCode);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            // ignore: use_build_context_synchronously
            content: Text(context.tr('settings.language_changed')),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error changing language: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // ignore: use_build_context_synchronously
              context.tr(
                'settings.error_changing_language',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changeCurrency(
    BuildContext context,
    String currencyCode,
  ) async {
    final configProvider = context.read<AppConfigProvider>();
    if (configProvider.currency == currencyCode) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await configProvider.setCurrency(currencyCode);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            // ignore: use_build_context_synchronously
            content: Text(context.tr('settings.currency_changed')),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error changing currency: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // ignore: use_build_context_synchronously
              context.tr(
                'settings.error_changing_currency',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changeThemeMode(
    BuildContext context,
    String themeModeCode,
  ) async {
    final configProvider = context.read<AppConfigProvider>();
    if (configProvider.themeMode == themeModeCode) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await configProvider.setThemeMode(themeModeCode);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            // ignore: use_build_context_synchronously
            content: Text(context.tr('settings.theme_changed')),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error changing theme: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // ignore: use_build_context_synchronously
              context.tr(
                'settings.error_changing_theme',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // Export Dialog
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.tr('settings.export_data')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dialogContext.tr('settings.export_format')),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _handleExport(context, 'csv');
                      },
                      icon: const Icon(Icons.table_chart),
                      label: Text(dialogContext.tr('settings.export_csv')),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _handleExport(context, 'json');
                      },
                      icon: const Icon(Icons.code),
                      label: Text(dialogContext.tr('settings.export_json')),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('common.cancel')),
            ),
          ],
        );
      },
    );
  }

  // Handle Export
  Future<void> _handleExport(BuildContext context, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Text('Exporting...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final expenses = expenseProvider.expenses;
      final categories = categoryProvider.categories;

      String filePath;
      if (format == 'csv') {
        // CSV only exports expenses (no categories)
        filePath = await ExportService.exportToCSV(expenses);
      } else {
        // JSON exports both expenses and categories (complete backup)
        filePath = await ExportService.exportToJSON(expenses, categories);
      }

      // Share the file
      await ExportService.shareFile(
        filePath,
        'quick_spend_export.$format',
      );

      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            // ignore: use_build_context_synchronously
            content: Text(context.tr('settings.export_success')),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error exporting: $e');
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // ignore: use_build_context_synchronously
              context.tr(
                'settings.export_error',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Handle Import
  Future<void> _handleImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final configProvider = context.read<AppConfigProvider>();

    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('⚠️ [SettingsScreen] No file selected');
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        debugPrint('⚠️ [SettingsScreen] File path is null');
        return;
      }

      final extension = filePath.split('.').last.toLowerCase();
      debugPrint('📁 [SettingsScreen] Importing from: $filePath ($extension)');

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Text('Importing...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Import based on format
      final userId = 'user'; // TODO: Get actual user ID
      final existingExpenses = expenseProvider.expenses;
      final existingCategories = categoryProvider.categories;

      ImportResult importResult;
      if (extension == 'csv') {
        importResult = await ImportService.importFromCSV(
          filePath,
          userId,
          existingExpenses,
          existingCategories,
        );
      } else if (extension == 'json') {
        importResult = await ImportService.importFromJSON(
          filePath,
          userId,
          existingExpenses,
          existingCategories,
        );
      } else {
        throw Exception('Unsupported file format: $extension');
      }

      // Save imported categories first
      for (final category in importResult.importedCategories) {
        await categoryProvider.createCategory(category);
      }

      // Then save imported expenses
      for (final expense in importResult.importedExpenses) {
        await expenseProvider.addExpense(expense);
      }

      if (mounted) {
        messenger.clearSnackBars();

        // Build success message with category info if applicable
        String message;
        if (importResult.categoriesImported > 0) {
          message =
              'Imported ${importResult.categoriesImported} categories, ${importResult.successCount} expenses';
          if (importResult.categoriesSkipped > 0) {
            message += ' (${importResult.categoriesSkipped} categories skipped)';
          }
          if (importResult.failureCount > 0) {
            message += ', ${importResult.failureCount} failed';
          }
          if (importResult.duplicateCount > 0) {
            message += ', ${importResult.duplicateCount} duplicates';
          }
        } else {
          // ignore: use_build_context_synchronously
          message = context.tr(
            'settings.import_success',
            namedArgs: {
              'success': importResult.successCount.toString(),
              'failed': importResult.failureCount.toString(),
              'duplicates': importResult.duplicateCount.toString(),
            },
          );
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: importResult.hasErrors
                ? AppTheme.warning
                : AppTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error importing: $e');
      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              // ignore: use_build_context_synchronously
              context.tr(
                'settings.import_error',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

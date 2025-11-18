// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/data_collection_service.dart';
import '../theme/app_theme.dart';
import 'categories_screen.dart';
import 'recurring_expenses_screen.dart';
import 'feedback_form_screen.dart';
import 'feedback_admin_screen.dart';

/// Settings screen for changing app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  int _debugTapCount = 0;
  DateTime? _lastTapTime;
  bool _debugModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadDebugMode();
  }

  Future<void> _loadDebugMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _debugModeEnabled = prefs.getBool('debug_mode') ?? false;
      });
    }
  }

  Future<void> _toggleDebugMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _debugModeEnabled = !_debugModeEnabled;
    });
    await prefs.setBool('debug_mode', _debugModeEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _debugModeEnabled
                ? '🐛 Debug mode ENABLED'
                : '✅ Debug mode DISABLED',
          ),
          backgroundColor: _debugModeEnabled
              ? AppTheme.warning
              : AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleLogoTap() {
    final now = DateTime.now();

    // Reset counter if more than 3 seconds since last tap
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!).inMilliseconds > 3000) {
      _debugTapCount = 1;
    } else {
      _debugTapCount++;
    }

    _lastTapTime = now;

    // Activate debug mode after 5 taps
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      _showDebugMenu();
    }
  }

  void _showDebugMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Debug Menu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug mode allows you to:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const Text('• Force parser selection (AI/Fallback)'),
            const Text('• View confidence scores'),
            const Text('• Access detailed logs'),
            const Text('• Monitor performance'),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Debug Mode'),
              subtitle: Text(
                _debugModeEnabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: _debugModeEnabled ? AppTheme.success : AppTheme.error,
                ),
              ),
              value: _debugModeEnabled,
              onChanged: (value) {
                Navigator.pop(context);
                _toggleDebugMode();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.feedback, color: AppTheme.accentOrange),
              title: const Text('View Feedback'),
              subtitle: const Text('Admin: View all user feedback'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackAdminScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      // If package info fails, fall back to pubspec version
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0';
        });
      }
    }
  }

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
                      icon: Icons.repeat,
                      iconColor: AppTheme.accentPink,
                      title: context.tr('recurring.title'),
                      subtitle: context.tr('recurring.manage_templates'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RecurringExpensesScreen(),
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
                      description: context.tr('settings.language_description'),
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
                      description: context.tr('settings.export_data_description'),
                      onTap: () => _showExportDialog(context),
                    ),

                    _buildListTile(
                      icon: Icons.download,
                      iconColor: AppTheme.info,
                      title: context.tr('settings.import_data'),
                      subtitle: context.tr('settings.import_data_subtitle'),
                      description: context.tr('settings.import_data_description'),
                      onTap: () => _handleImport(context),
                    ),

                    _buildDataCollectionTile(context),

                    const Divider(height: 32),

                    // Support & Feedback Section
                    _buildSectionHeader(context.tr('feedback.section_header')),

                    _buildListTile(
                      icon: Icons.feedback_outlined,
                      iconColor: AppTheme.accentOrange,
                      title: context.tr('feedback.send_feedback'),
                      subtitle: context.tr('feedback.send_feedback_subtitle'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FeedbackFormScreen(),
                          ),
                        );
                      },
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
                            GestureDetector(
                              onTap: _handleLogoTap,
                              child: Container(
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
                                    _appVersion.isEmpty
                                        ? context.tr('settings.version')
                                        : 'v$_appVersion',
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
                                  if (_debugModeEnabled) ...[
                                    const SizedBox(height: AppTheme.spacing8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppTheme.warning.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.bug_report,
                                            size: 14,
                                            color: AppTheme.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Debug Mode Active',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: AppTheme.warning,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
    String? description,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppTheme.spacing4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 11,
                ),
              ),
            ],
          ],
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
      case 'en':
        return context.tr('settings.language_en');
      case 'vi':
        return context.tr('settings.language_vi');
      case 'ja':
        return context.tr('settings.language_ja');
      case 'ko':
        return context.tr('settings.language_ko');
      case 'th':
        return context.tr('settings.language_th');
      case 'es':
        return context.tr('settings.language_es');
      default:
        return context.tr('settings.language_en');
    }
  }

  String _getCurrencyDisplayName(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return context.tr('settings.currency_usd_display');
      case 'VND':
        return context.tr('settings.currency_vnd_display');
      case 'JPY':
        return context.tr('settings.currency_jpy_display');
      case 'KRW':
        return context.tr('settings.currency_krw_display');
      case 'THB':
        return context.tr('settings.currency_thb_display');
      case 'EUR':
        return context.tr('settings.currency_eur_display');
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

  // Export to JSON (removed CSV option since it doesn't include categories)
  void _showExportDialog(BuildContext context) {
    _handleExport(context, 'json');
  }

  // Handle Export (JSON only - includes all categories, expenses, and settings)
  Future<void> _handleExport(BuildContext context, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final configProvider = context.read<AppConfigProvider>();

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
                Text(context.tr('settings.exporting')),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      final expenses = expenseProvider.expenses;
      final categories = categoryProvider.categories;
      final appConfig = configProvider.config;

      // JSON exports expenses, categories, and app settings (complete backup)
      final filePath = await ExportService.exportToJSON(
        expenses,
        categories,
        appConfig,
      );

      // Calculate share position origin for iOS (required for iPad popover)
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Share the file with localized strings
      await ExportService.shareFile(
        filePath,
        'quick_spend_export.json',
        subject: context.tr('settings.share_subject'),
        text: context.tr('settings.share_text'),
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
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
      // Pick JSON file only (CSV doesn't include categories)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
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

      debugPrint('📁 [SettingsScreen] Importing from: $filePath');

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
                Text(context.tr('settings.importing')),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      // Import from JSON (includes all categories and expenses)
      final userId = expenseProvider.currentUserId;
      final existingExpenses = expenseProvider.expenses;
      final existingCategories = categoryProvider.categories;

      final importResult = await ImportService.importFromJSON(
        filePath,
        userId,
        existingExpenses,
        existingCategories,
      );

      // Save imported categories first (import file has higher priority)
      for (final category in importResult.importedCategories) {
        final exists = existingCategories.any((c) => c.id == category.id);
        if (exists) {
          // skip 'other' & 'other_income' built-in categories
          if (category.id == 'other' || category.id == 'other_income') {
            debugPrint(
              'ℹ️ [SettingsScreen] Skipping built-in category: ${category.name}',
            );
            continue;
          }
          // Override existing category with imported data
          await categoryProvider.updateCategory(category);
          debugPrint(
            '🔄 [SettingsScreen] Updated category: ${category.name}',
          );
        } else {
          // Create new category
          await categoryProvider.createCategory(category);
          debugPrint('➕ [SettingsScreen] Created category: ${category.name}');
        }
      }

      // Then save imported expenses
      for (final expense in importResult.importedExpenses) {
        await expenseProvider.addExpense(expense);
      }

      // Apply imported settings if available
      if (importResult.hasSettings) {
        debugPrint(
          '⚙️ [SettingsScreen] Applying imported settings: language=${importResult.language}, currency=${importResult.currency}',
        );

        if (importResult.language != null &&
            importResult.language != configProvider.language) {
          // Find the language option to get country code
          final languageOption = LanguageOption.options.firstWhere(
            (opt) => opt.code == importResult.language,
            orElse: () => LanguageOption.options.first,
          );

          // Update locale
          await context.setLocale(
            Locale(languageOption.code, languageOption.countryCode),
          );

          // Update provider
          await configProvider.setLanguage(importResult.language!);
          debugPrint(
            '✅ [SettingsScreen] Language updated to: ${importResult.language}',
          );
        }

        if (importResult.currency != null &&
            importResult.currency != configProvider.currency) {
          await configProvider.setCurrency(importResult.currency!);
          debugPrint(
            '✅ [SettingsScreen] Currency updated to: ${importResult.currency}',
          );
        }
      }

      if (mounted) {
        messenger.clearSnackBars();

        // Build success message with category and settings info if applicable
        String message;
        if (importResult.categoriesImported > 0) {
          message = context.tr(
            'settings.import_success_with_categories',
            namedArgs: {
              'categories': importResult.categoriesImported.toString(),
              'expenses': importResult.successCount.toString(),
            },
          );
          if (importResult.failureCount > 0) {
            message += context.tr(
              'settings.import_failed_count',
              namedArgs: {'count': importResult.failureCount.toString()},
            );
          }
          if (importResult.duplicateCount > 0) {
            message += context.tr(
              'settings.import_duplicate_count',
              namedArgs: {'count': importResult.duplicateCount.toString()},
            );
          }
        } else {
          message = context.tr(
            'settings.import_success',
            namedArgs: {
              'success': importResult.successCount.toString(),
              'failed': importResult.failureCount.toString(),
              'duplicates': importResult.duplicateCount.toString(),
            },
          );
        }

        // Add settings import info if applicable
        if (importResult.hasSettings) {
          final settingsParts = <String>[];
          if (importResult.language != null) {
            settingsParts.add(
              'language: ${importResult.language}',
            );
          }
          if (importResult.currency != null) {
            settingsParts.add(
              'currency: ${importResult.currency}',
            );
          }
          if (settingsParts.isNotEmpty) {
            message += '\n⚙️ Settings restored: ${settingsParts.join(", ")}';
          }
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

  /// Build data collection consent tile
  Widget _buildDataCollectionTile(BuildContext context) {
    final dataCollectionService = context.read<DataCollectionService>();

    return FutureBuilder<bool>(
      future: dataCollectionService.hasConsent(),
      builder: (context, snapshot) {
        final hasConsent = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing8,
          ),
          child: SwitchListTile(
            secondary: const Icon(Icons.insights, color: AppTheme.accentPink),
            title: Text(context.tr('data_collection.settings_title')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  context.tr('data_collection.settings_subtitle'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  context.tr('data_collection.settings_description'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.neutral50,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            value: hasConsent,
            onChanged: (bool value) async {
              await dataCollectionService.setConsent(value);
              setState(() {}); // Refresh UI

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? context.tr('data_collection.enabled_message')
                          : context.tr('data_collection.disabled_message'),
                    ),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

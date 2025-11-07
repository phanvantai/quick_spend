import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/app_config.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';

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
                title: option.displayName,
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
        // Wait a frame for the rebuild to complete
        await Future.delayed(const Duration(milliseconds: 100));

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
}

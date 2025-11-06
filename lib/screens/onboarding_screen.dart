import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/app_config.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/gradient_button.dart';
import 'main_screen.dart';

/// Onboarding screen with multi-step flow
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late String _selectedLanguage;
  String _selectedCurrency = 'USD';
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize with current locale (only once)
    if (!_isInitialized) {
      _selectedLanguage = context.locale.languageCode;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final configProvider = context.read<AppConfigProvider>();

    await configProvider.updatePreferences(
      language: _selectedLanguage,
      currency: _selectedCurrency,
      isOnboardingComplete: true,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
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
          body: SafeArea(
            child: Column(
              children: [
                // Page indicator
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing4,
                        ),
                        width: _currentPage == index ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: _currentPage == index
                              ? AppTheme.primaryGradient
                              : null,
                          color: _currentPage == index
                              ? null
                              : colorScheme.outline,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // PageView
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildWelcomePage(),
                      _buildLanguagePage(),
                      _buildCurrencyPage(),
                    ],
                  ),
                ),
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            child: Text(context.tr('onboarding.back')),
                          ),
                        ),
                      if (_currentPage > 0)
                        const SizedBox(width: AppTheme.spacing16),
                      Expanded(
                        child: GradientButton(
                          text: _currentPage == 2
                              ? context.tr('onboarding.get_started')
                              : context.tr('onboarding.next'),
                          icon: _currentPage == 2
                              ? Icons.check
                              : Icons.arrow_forward,
                          onPressed: _nextPage,
                          gradient: AppTheme.primaryGradient,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Welcome page
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gradient icon
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wallet_rounded,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),
          Text(
            context.tr('app.name'),
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            context.tr('app.tagline'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing48),
          _buildFeatureItem(
            Icons.speed,
            context.tr('onboarding.feature_quick_entry'),
            context.tr('onboarding.feature_quick_entry_desc'),
            AppTheme.accentOrange,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildFeatureItem(
            Icons.language,
            context.tr('onboarding.feature_bilingual'),
            context.tr('onboarding.feature_bilingual_desc'),
            AppTheme.accentTeal,
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildFeatureItem(
            Icons.auto_awesome,
            context.tr('onboarding.feature_smart_categories'),
            context.tr('onboarding.feature_smart_categories_desc'),
            AppTheme.accentPink,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: AppTheme.borderRadiusMedium,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(
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
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Language selection page
  Widget _buildLanguagePage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacing40),
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language, size: 56, color: Colors.white),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.tr('onboarding.choose_language'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.tr('onboarding.select_language_subtitle'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing48),
          ...LanguageOption.options.map((option) {
            return _OptionCard(
              isSelected: _selectedLanguage == option.code,
              onTap: () async {
                setState(() {
                  _selectedLanguage = option.code;
                });
                // Update locale immediately for preview
                await context.setLocale(
                  Locale(option.code, option.countryCode),
                );
              },
              leading: Text(option.flag, style: const TextStyle(fontSize: 32)),
              title: option.displayName,
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  // Currency selection page
  Widget _buildCurrencyPage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacing40),
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.attach_money,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            context.tr('onboarding.choose_currency'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.tr('onboarding.select_currency_subtitle'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing48),
          ...CurrencyOption.options.map((option) {
            return _OptionCard(
              isSelected: _selectedCurrency == option.code,
              onTap: () {
                setState(() {
                  _selectedCurrency = option.code;
                });
              },
              leading: Text(
                option.symbol,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: option.displayName,
              subtitle: option.code,
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Reusable option card widget
class _OptionCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;

  const _OptionCard({
    required this.isSelected,
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.borderRadiusMedium,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppTheme.primaryMint : colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: AppTheme.borderRadiusMedium,
              color: isSelected
                  ? AppTheme.primaryMint.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest,
              boxShadow: isSelected ? AppTheme.shadowSmall : null,
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
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing4),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../services/preferences_service.dart';
import '../services/analytics_service.dart';

/// Provider for managing app configuration state
class AppConfigProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;
  final AnalyticsService? _analyticsService;
  AppConfig _config = const AppConfig();
  bool _isLoading = true;

  AppConfigProvider(
    this._preferencesService, {
    AnalyticsService? analyticsService,
  }) : _analyticsService = analyticsService {
    _loadConfig();
  }

  /// Current app configuration
  AppConfig get config => _config;

  /// Whether the provider is loading
  bool get isLoading => _isLoading;

  /// Current language
  String get language => _config.language;

  /// Current currency
  String get currency => _config.currency;

  /// Current theme mode
  String get themeMode => _config.themeMode;

  /// Whether onboarding is complete
  bool get isOnboardingComplete => _config.isOnboardingComplete;

  /// Load configuration from preferences
  Future<void> _loadConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      _config = await _preferencesService.getConfig();
    } catch (e) {
      debugPrint('Error loading config: $e');
      _config = const AppConfig();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update language
  Future<void> setLanguage(String language) async {
    final oldLanguage = _config.language;
    final newConfig = _config.copyWith(language: language);
    await _updateConfig(newConfig);

    // Log analytics
    _analyticsService?.logLanguageChanged(
      fromLanguage: oldLanguage,
      toLanguage: language,
    );
    _analyticsService?.setLanguageProperty(language);
  }

  /// Update currency
  Future<void> setCurrency(String currency) async {
    final oldCurrency = _config.currency;
    final newConfig = _config.copyWith(currency: currency);
    await _updateConfig(newConfig);

    // Log analytics
    _analyticsService?.logCurrencyChanged(
      fromCurrency: oldCurrency,
      toCurrency: currency,
    );
    _analyticsService?.setCurrencyProperty(currency);
  }

  /// Update theme mode
  Future<void> setThemeMode(String themeMode) async {
    final oldThemeMode = _config.themeMode;
    final newConfig = _config.copyWith(themeMode: themeMode);
    await _updateConfig(newConfig);

    // Log analytics
    _analyticsService?.logThemeChanged(
      fromTheme: oldThemeMode,
      toTheme: themeMode,
    );
    _analyticsService?.setThemeModeProperty(themeMode);
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final newConfig = _config.copyWith(isOnboardingComplete: true);
    await _updateConfig(newConfig);
  }

  /// Update both language and currency (useful for onboarding)
  Future<void> updatePreferences({
    String? language,
    String? currency,
    bool? isOnboardingComplete,
  }) async {
    final newConfig = _config.copyWith(
      language: language,
      currency: currency,
      isOnboardingComplete: isOnboardingComplete,
    );
    await _updateConfig(newConfig);
  }

  /// Internal method to update config
  Future<void> _updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    notifyListeners();

    try {
      await _preferencesService.saveConfig(newConfig);
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  /// Reset to default configuration (for testing)
  Future<void> reset() async {
    await _preferencesService.clearAll();
    await _loadConfig();
  }
}

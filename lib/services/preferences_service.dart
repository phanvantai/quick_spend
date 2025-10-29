import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

/// Service for managing app preferences using SharedPreferences
class PreferencesService {
  static const String _configKey = 'app_config';

  SharedPreferences? _prefs;

  /// Initialize the preferences service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get app configuration
  Future<AppConfig> getConfig() async {
    await _ensureInitialized();

    final jsonString = _prefs!.getString(_configKey);
    if (jsonString == null) {
      // Return default config
      return const AppConfig();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (e) {
      // If parsing fails, return default config
      return const AppConfig();
    }
  }

  /// Save app configuration
  Future<void> saveConfig(AppConfig config) async {
    await _ensureInitialized();

    final jsonString = jsonEncode(config.toJson());
    await _prefs!.setString(_configKey, jsonString);
  }

  /// Update language
  Future<void> setLanguage(String language) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(language: language));
  }

  /// Update currency
  Future<void> setCurrency(String currency) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(currency: currency));
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final config = await getConfig();
    await saveConfig(config.copyWith(isOnboardingComplete: true));
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    final config = await getConfig();
    return config.isOnboardingComplete;
  }

  /// Clear all preferences (for testing/debugging)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs!.clear();
  }

  /// Ensure preferences are initialized
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }
}

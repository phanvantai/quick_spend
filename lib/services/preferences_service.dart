import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';

/// Service for managing app preferences using SharedPreferences
class PreferencesService {
  static const String _configKey = 'app_config';
  static const String _voiceTutorialShownKey = 'voice_tutorial_shown';
  static const String _voiceRecordingCountKey = 'voice_recording_count';

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

  /// Set data collection consent
  Future<void> setDataCollectionConsent(bool consent) async {
    final config = await getConfig();
    await saveConfig(config.copyWith(dataCollectionConsent: consent));
  }

  /// Get data collection consent
  Future<bool> getDataCollectionConsent() async {
    final config = await getConfig();
    return config.dataCollectionConsent;
  }

  /// Clear all preferences (for testing/debugging)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs!.clear();
  }

  // ============================================
  // Voice Tutorial Tracking
  // ============================================

  /// Check if voice tutorial has been shown
  Future<bool> hasShownVoiceTutorial() async {
    await _ensureInitialized();
    return _prefs!.getBool(_voiceTutorialShownKey) ?? false;
  }

  /// Mark voice tutorial as shown
  Future<void> markVoiceTutorialShown() async {
    await _ensureInitialized();
    await _prefs!.setBool(_voiceTutorialShownKey, true);
  }

  /// Get the number of times user has recorded voice input
  Future<int> getVoiceRecordingCount() async {
    await _ensureInitialized();
    return _prefs!.getInt(_voiceRecordingCountKey) ?? 0;
  }

  /// Increment voice recording count
  Future<void> incrementVoiceRecordingCount() async {
    await _ensureInitialized();
    final count = await getVoiceRecordingCount();
    await _prefs!.setInt(_voiceRecordingCountKey, count + 1);
  }

  /// Check if we should show pulsing hint (first 3 uses after tutorial)
  Future<bool> shouldShowVoicePulsingHint() async {
    final tutorialShown = await hasShownVoiceTutorial();
    final recordingCount = await getVoiceRecordingCount();
    // Show pulsing hint for first 3 uses after tutorial is dismissed
    return tutorialShown && recordingCount < 3;
  }

  /// Ensure preferences are initialized
  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }
}

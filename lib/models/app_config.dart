import 'package:flutter/material.dart';

/// App configuration model for user preferences
class AppConfig {
  final String language; // 'en' or 'vi'
  final String currency; // 'USD', 'VND'
  final String themeMode; // 'light', 'dark', 'system'
  final bool isOnboardingComplete;

  const AppConfig({
    this.language = 'en',
    this.currency = 'USD',
    this.themeMode = 'system',
    this.isOnboardingComplete = false,
  });

  /// Create config from JSON
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'USD',
      themeMode: json['themeMode'] as String? ?? 'system',
      isOnboardingComplete: json['isOnboardingComplete'] as bool? ?? false,
    );
  }

  /// Convert config to JSON
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'currency': currency,
      'themeMode': themeMode,
      'isOnboardingComplete': isOnboardingComplete,
    };
  }

  /// Create a copy with modified fields
  AppConfig copyWith({
    String? language,
    String? currency,
    String? themeMode,
    bool? isOnboardingComplete,
  }) {
    return AppConfig(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'VND':
        return 'đ';
      case 'USD':
        return '\$';
      default:
        return currency;
    }
  }

  /// Get language display name
  String get languageDisplayName {
    switch (language) {
      case 'vi':
        return 'Tiếng Việt';
      case 'en':
        return 'English';
      default:
        return language;
    }
  }

  @override
  String toString() {
    return 'AppConfig(language: $language, currency: $currency, themeMode: $themeMode, isOnboardingComplete: $isOnboardingComplete)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppConfig &&
        other.language == language &&
        other.currency == currency &&
        other.themeMode == themeMode &&
        other.isOnboardingComplete == isOnboardingComplete;
  }

  @override
  int get hashCode {
    return Object.hash(language, currency, themeMode, isOnboardingComplete);
  }
}

/// Language option for selection
class LanguageOption {
  final String code;
  final String countryCode;
  final String displayName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.countryCode,
    required this.displayName,
    required this.flag,
  });

  static const List<LanguageOption> options = [
    LanguageOption(
      code: 'en',
      displayName: 'English',
      flag: '🇺🇸',
      countryCode: 'US',
    ),
    LanguageOption(
      code: 'vi',
      displayName: 'Tiếng Việt',
      flag: '🇻🇳',
      countryCode: 'VN',
    ),
  ];
}

/// Currency option for selection
class CurrencyOption {
  final String code;
  final String displayName;
  final String symbol;

  const CurrencyOption({
    required this.code,
    required this.displayName,
    required this.symbol,
  });

  static const List<CurrencyOption> options = [
    CurrencyOption(code: 'USD', displayName: 'US Dollar', symbol: '\$'),
    CurrencyOption(code: 'VND', displayName: 'Vietnamese Dong', symbol: 'đ'),
  ];
}

/// Theme mode option for selection
class ThemeModeOption {
  final String code;
  final String displayNameKey; // Translation key
  final IconData icon;

  const ThemeModeOption({
    required this.code,
    required this.displayNameKey,
    required this.icon,
  });

  static const List<ThemeModeOption> options = [
    ThemeModeOption(
      code: 'light',
      displayNameKey: 'settings.theme_light',
      icon: Icons.light_mode,
    ),
    ThemeModeOption(
      code: 'dark',
      displayNameKey: 'settings.theme_dark',
      icon: Icons.dark_mode,
    ),
    ThemeModeOption(
      code: 'system',
      displayNameKey: 'settings.theme_system',
      icon: Icons.brightness_auto,
    ),
  ];
}

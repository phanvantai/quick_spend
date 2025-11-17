import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// App configuration model for user preferences
class AppConfig {
  final String language; // 'en' or 'vi'
  final String currency; // 'USD', 'VND'
  final String themeMode; // 'light', 'dark', 'system'
  final bool isOnboardingComplete;
  final bool dataCollectionConsent; // User consent for training data collection

  const AppConfig({
    this.language = 'en',
    this.currency = 'USD',
    this.themeMode = 'system',
    this.isOnboardingComplete = false,
    this.dataCollectionConsent = false,
  });

  /// Create config from JSON
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'USD',
      themeMode: json['themeMode'] as String? ?? 'system',
      isOnboardingComplete: json['isOnboardingComplete'] as bool? ?? false,
      dataCollectionConsent: json['dataCollectionConsent'] as bool? ?? false,
    );
  }

  /// Convert config to JSON
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'currency': currency,
      'themeMode': themeMode,
      'isOnboardingComplete': isOnboardingComplete,
      'dataCollectionConsent': dataCollectionConsent,
    };
  }

  /// Create a copy with modified fields
  AppConfig copyWith({
    String? language,
    String? currency,
    String? themeMode,
    bool? isOnboardingComplete,
    bool? dataCollectionConsent,
  }) {
    return AppConfig(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      dataCollectionConsent: dataCollectionConsent ?? this.dataCollectionConsent,
    );
  }

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'VND':
        return 'đ';
      case 'USD':
        return '\$';
      case 'JPY':
        return '¥';
      case 'KRW':
        return '₩';
      case 'THB':
        return '฿';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  /// Format currency amount with proper symbol placement and number formatting
  /// This method handles:
  /// - Decimal places based on currency (VND, JPY, KRW don't use decimals)
  /// - Thousand/decimal separators based on language
  /// - Currency symbol position based on currency conventions
  String formatCurrency(double amount) {
    // Determine decimal places based on currency
    // VND, JPY, KRW don't use decimal places
    final useDecimals = currency != 'VND' && currency != 'JPY' && currency != 'KRW';

    // Determine thousand/decimal separators based on language
    // Vietnamese and Spanish: period for thousands, comma for decimals
    // Others: comma for thousands, period for decimals
    final usePeriodForThousands = language == 'vi' || language == 'es';

    // Create formatter with en_US locale first
    final formatter = NumberFormat(
      useDecimals ? '#,##0.00' : '#,##0',
      'en_US',
    );

    String formatted = formatter.format(amount);

    // Swap separators if needed for Vietnamese/Spanish
    if (usePeriodForThousands) {
      formatted = formatted.replaceAll(',', '|'); // Temp placeholder
      formatted = formatted.replaceAll('.', ','); // Decimal comma
      formatted = formatted.replaceAll('|', '.'); // Thousand period
    }

    // Determine symbol position based on currency
    // Currencies with symbol AFTER value: VND, THB
    // Currencies with symbol BEFORE value: USD, EUR, JPY, KRW
    final symbolAfter = currency == 'VND' || currency == 'THB';

    if (symbolAfter) {
      return '$formatted $currencySymbol';
    } else {
      return '$currencySymbol$formatted';
    }
  }

  /// Get language display name
  String get languageDisplayName {
    switch (language) {
      case 'vi':
        return 'Tiếng Việt';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'th':
        return 'ไทย';
      case 'es':
        return 'Español';
      default:
        return language;
    }
  }

  @override
  String toString() {
    return 'AppConfig(language: $language, currency: $currency, themeMode: $themeMode, isOnboardingComplete: $isOnboardingComplete, dataCollectionConsent: $dataCollectionConsent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppConfig &&
        other.language == language &&
        other.currency == currency &&
        other.themeMode == themeMode &&
        other.isOnboardingComplete == isOnboardingComplete &&
        other.dataCollectionConsent == dataCollectionConsent;
  }

  @override
  int get hashCode {
    return Object.hash(language, currency, themeMode, isOnboardingComplete, dataCollectionConsent);
  }
}

/// Language option for selection
class LanguageOption {
  final String code;
  final String countryCode;
  final String displayName;
  final String flag;
  final String defaultCurrency; // Default currency for this language

  const LanguageOption({
    required this.code,
    required this.countryCode,
    required this.displayName,
    required this.flag,
    required this.defaultCurrency,
  });

  static const List<LanguageOption> options = [
    LanguageOption(
      code: 'en',
      displayName: 'English',
      flag: '🇺🇸',
      countryCode: 'US',
      defaultCurrency: 'USD',
    ),
    LanguageOption(
      code: 'vi',
      displayName: 'Tiếng Việt',
      flag: '🇻🇳',
      countryCode: 'VN',
      defaultCurrency: 'VND',
    ),
    LanguageOption(
      code: 'ja',
      displayName: '日本語',
      flag: '🇯🇵',
      countryCode: 'JP',
      defaultCurrency: 'JPY',
    ),
    LanguageOption(
      code: 'ko',
      displayName: '한국어',
      flag: '🇰🇷',
      countryCode: 'KR',
      defaultCurrency: 'KRW',
    ),
    LanguageOption(
      code: 'th',
      displayName: 'ไทย',
      flag: '🇹🇭',
      countryCode: 'TH',
      defaultCurrency: 'THB',
    ),
    LanguageOption(
      code: 'es',
      displayName: 'Español',
      flag: '🇪🇸',
      countryCode: 'ES',
      defaultCurrency: 'EUR',
    ),
  ];

  /// Get default currency for a language code
  static String getDefaultCurrency(String languageCode) {
    final option = options.firstWhere(
      (opt) => opt.code == languageCode,
      orElse: () => options.first,
    );
    return option.defaultCurrency;
  }
}

/// Currency option for selection
class CurrencyOption {
  final String code;
  final String displayNameKey; // Translation key
  final String symbol;

  const CurrencyOption({
    required this.code,
    required this.displayNameKey,
    required this.symbol,
  });

  static const List<CurrencyOption> options = [
    CurrencyOption(code: 'USD', displayNameKey: 'currencies.usd.name', symbol: '\$'),
    CurrencyOption(code: 'VND', displayNameKey: 'currencies.vnd.name', symbol: 'đ'),
    CurrencyOption(code: 'JPY', displayNameKey: 'currencies.jpy.name', symbol: '¥'),
    CurrencyOption(code: 'KRW', displayNameKey: 'currencies.krw.name', symbol: '₩'),
    CurrencyOption(code: 'THB', displayNameKey: 'currencies.thb.name', symbol: '฿'),
    CurrencyOption(code: 'EUR', displayNameKey: 'currencies.eur.name', symbol: '€'),
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

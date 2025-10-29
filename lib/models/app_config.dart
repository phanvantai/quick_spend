/// App configuration model for user preferences
class AppConfig {
  final String language; // 'en' or 'vi'
  final String currency; // 'USD', 'VND'
  final bool isOnboardingComplete;

  const AppConfig({
    this.language = 'en',
    this.currency = 'USD',
    this.isOnboardingComplete = false,
  });

  /// Create config from JSON
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'USD',
      isOnboardingComplete: json['isOnboardingComplete'] as bool? ?? false,
    );
  }

  /// Convert config to JSON
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'currency': currency,
      'isOnboardingComplete': isOnboardingComplete,
    };
  }

  /// Create a copy with modified fields
  AppConfig copyWith({
    String? language,
    String? currency,
    bool? isOnboardingComplete,
  }) {
    return AppConfig(
      language: language ?? this.language,
      currency: currency ?? this.currency,
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
    return 'AppConfig(language: $language, currency: $currency, isOnboardingComplete: $isOnboardingComplete)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppConfig &&
        other.language == language &&
        other.currency == currency &&
        other.isOnboardingComplete == isOnboardingComplete;
  }

  @override
  int get hashCode {
    return Object.hash(language, currency, isOnboardingComplete);
  }
}

/// Language option for selection
class LanguageOption {
  final String code;
  final String displayName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.displayName,
    required this.flag,
  });

  static const List<LanguageOption> options = [
    LanguageOption(
      code: 'en',
      displayName: 'English',
      flag: '🇺🇸',
    ),
    LanguageOption(
      code: 'vi',
      displayName: 'Tiếng Việt',
      flag: '🇻🇳',
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
    CurrencyOption(
      code: 'USD',
      displayName: 'US Dollar',
      symbol: '\$',
    ),
    CurrencyOption(
      code: 'VND',
      displayName: 'Vietnamese Dong',
      symbol: 'đ',
    ),
  ];
}

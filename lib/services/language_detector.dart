/// Service for detecting language (English or Vietnamese) from text
class LanguageDetector {
  // Vietnamese diacritics and characters
  static final _vietnameseCharPattern = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]',
    caseSensitive: false,
  );

  // Common Vietnamese keywords
  static const _vietnameseKeywords = [
    // Food
    'ăn',
    'cơm',
    'phở',
    'bún',
    'cà phê',
    'cafe',
    'trà',
    'nước',
    'uống',
    'sáng',
    'trưa',
    'tối',
    'quán',
    // Transport
    'xe',
    'xăng',
    'dầu',
    'taxi',
    'grab',
    // Shopping
    'mua',
    'shopping',
    'quần',
    'áo',
    'giày',
    'dép',
    'váy',
    // Bills
    'tiền',
    'điện',
    'nước',
    'nhà',
    // Health
    'thuốc',
    'bác sĩ',
    'bệnh viện',
    // Entertainment
    'phim',
    'rạp',
    'game',
    // Number words
    'nghìn',
    'ngàn',
    'triệu',
    'trieu',
    'tr',
    'đồng',
  ];

  /// Detect language from text
  /// Returns 'vi' for Vietnamese, 'en' for English
  static String detectLanguage(String text) {
    if (text.isEmpty) return 'en';

    final normalizedText = text.toLowerCase().trim();

    // Check for Vietnamese diacritics
    if (_vietnameseCharPattern.hasMatch(normalizedText)) {
      return 'vi';
    }

    // Check for Vietnamese keywords
    for (final keyword in _vietnameseKeywords) {
      if (normalizedText.contains(keyword)) {
        return 'vi';
      }
    }

    // Default to English
    return 'en';
  }

  /// Check if text contains Vietnamese characters
  static bool hasVietnameseChars(String text) {
    return _vietnameseCharPattern.hasMatch(text);
  }

  /// Get confidence score for language detection (0-1)
  /// Higher score means more confident
  static double getConfidence(String text, String detectedLanguage) {
    if (text.isEmpty) return 0.5;

    final normalizedText = text.toLowerCase().trim();
    double score = 0.5; // Base score

    if (detectedLanguage == 'vi') {
      // Check for Vietnamese indicators
      if (_vietnameseCharPattern.hasMatch(normalizedText)) {
        score += 0.3; // Strong indicator
      }

      // Count Vietnamese keywords
      int keywordCount = 0;
      for (final keyword in _vietnameseKeywords) {
        if (normalizedText.contains(keyword)) {
          keywordCount++;
        }
      }

      // Add score based on keyword count
      if (keywordCount > 0) {
        score += (keywordCount * 0.1).clamp(0.0, 0.2);
      }
    } else {
      // English - if no Vietnamese indicators found, confidence is high
      if (!_vietnameseCharPattern.hasMatch(normalizedText)) {
        score += 0.3;
      }

      bool hasVietnameseKeyword = false;
      for (final keyword in _vietnameseKeywords) {
        if (normalizedText.contains(keyword)) {
          hasVietnameseKeyword = true;
          break;
        }
      }

      if (!hasVietnameseKeyword) {
        score += 0.2;
      }
    }

    return score.clamp(0.0, 1.0);
  }
}

/// Service for parsing amount strings into numerical values
/// Handles various formats:
/// - "50k" → 50,000
/// - "1.5m" or "1tr5" → 1,500,000
/// - "50 nghìn" → 50,000
/// - "100,000" → 100,000
/// - Plain numbers
class AmountParser {
  /// Parse amount from text and return the numerical value
  /// Returns null if no valid amount found
  static double? parseAmount(String text) {
    if (text.isEmpty) return null;

    text = text.trim().toLowerCase();

    // Try different parsing strategies
    double? amount;

    // Strategy 1: Look for Vietnamese number words
    amount = _parseVietnameseWords(text);
    if (amount != null) return amount;

    // Strategy 2: Look for k/m suffixes (English/Vietnamese)
    amount = _parseWithSuffix(text);
    if (amount != null) return amount;

    // Strategy 3: Look for formatted numbers with commas
    amount = _parseFormattedNumber(text);
    if (amount != null) return amount;

    // Strategy 4: Plain number
    amount = _parsePlainNumber(text);
    if (amount != null) return amount;

    return null;
  }

  /// Extract amount from input text and return both amount and remaining text
  static AmountParseResult? extractAmount(String text) {
    if (text.isEmpty) return null;

    text = text.trim();

    // Try to find amount with different patterns
    RegExp? matchedPattern;
    Match? match;

    // Pattern 1: Number with Vietnamese words (e.g., "50 nghìn", "1 triệu")
    final vietnamesePattern = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(nghìn|ngàn|triệu|tr|trieu)',
      caseSensitive: false,
    );
    match = vietnamesePattern.firstMatch(text);
    if (match != null) {
      matchedPattern = vietnamesePattern;
    }

    // Pattern 2: Number with k/m suffix (e.g., "50k", "1.5m", "1m5")
    if (match == null) {
      final suffixPattern = RegExp(
        r'(\d+(?:[.,]\d+)?)\s*([km])',
        caseSensitive: false,
      );
      match = suffixPattern.firstMatch(text);
      if (match != null) {
        matchedPattern = suffixPattern;
      }
    }

    // Pattern 3: Formatted number with commas (e.g., "100,000")
    if (match == null) {
      final formattedPattern = RegExp(r'(\d{1,3}(?:,\d{3})+)');
      match = formattedPattern.firstMatch(text);
      if (match != null) {
        matchedPattern = formattedPattern;
      }
    }

    // Pattern 4: Plain number (e.g., "50000")
    if (match == null) {
      final plainPattern = RegExp(r'(\d+(?:[.,]\d+)?)');
      match = plainPattern.firstMatch(text);
      if (match != null) {
        matchedPattern = plainPattern;
      }
    }

    if (match == null || matchedPattern == null) {
      return null;
    }

    // Extract the matched amount string
    final amountStr = match.group(0)!;
    final amount = parseAmount(amountStr);

    if (amount == null) return null;

    // Remove the amount from the original text to get description
    final description = text.replaceFirst(matchedPattern, '').trim();

    return AmountParseResult(
      amount: amount,
      description: description,
      rawAmount: amountStr,
    );
  }

  /// Parse Vietnamese number words
  static double? _parseVietnameseWords(String text) {
    // Match patterns like "50 nghìn", "1 triệu"
    final pattern = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(nghìn|ngàn|triệu|tr|trieu)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);

    if (match == null) return null;

    final numberStr = match.group(1)!.replaceAll(',', '.');
    final number = double.tryParse(numberStr);
    if (number == null) return null;

    final unit = match.group(2)!.toLowerCase();

    // Determine multiplier
    double multiplier = 1;
    if (unit == 'nghìn' || unit == 'ngàn') {
      multiplier = 1000;
    } else if (unit == 'triệu' || unit == 'tr' || unit == 'trieu') {
      multiplier = 1000000;
    }

    return number * multiplier;
  }

  /// Parse amounts with k/m suffix
  static double? _parseWithSuffix(String text) {
    // Match patterns like "50k", "1.5m", "1m5"
    final pattern = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*([km])',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);

    if (match == null) return null;

    final numberStr = match.group(1)!.replaceAll(',', '.');
    final number = double.tryParse(numberStr);
    if (number == null) return null;

    final suffix = match.group(2)!.toLowerCase();

    // Determine multiplier
    double multiplier = 1;
    if (suffix == 'k') {
      multiplier = 1000;
    } else if (suffix == 'm') {
      multiplier = 1000000;
    }

    return number * multiplier;
  }

  /// Parse formatted numbers with commas
  static double? _parseFormattedNumber(String text) {
    // Match patterns like "100,000"
    final pattern = RegExp(r'(\d{1,3}(?:,\d{3})+)');
    final match = pattern.firstMatch(text);

    if (match == null) return null;

    final numberStr = match.group(1)!.replaceAll(',', '');
    return double.tryParse(numberStr);
  }

  /// Parse plain numbers
  static double? _parsePlainNumber(String text) {
    // Match any number (integer or decimal)
    final pattern = RegExp(r'(\d+(?:[.,]\d+)?)');
    final match = pattern.firstMatch(text);

    if (match == null) return null;

    final numberStr = match.group(1)!.replaceAll(',', '.');
    return double.tryParse(numberStr);
  }
}

/// Result of amount extraction from text
class AmountParseResult {
  final double amount;
  final String description;
  final String rawAmount;

  AmountParseResult({
    required this.amount,
    required this.description,
    required this.rawAmount,
  });

  @override
  String toString() {
    return 'AmountParseResult(amount: $amount, description: $description, rawAmount: $rawAmount)';
  }
}

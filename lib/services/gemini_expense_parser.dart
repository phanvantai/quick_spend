import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import 'expense_parser.dart';

/// AI-powered expense parser using Firebase AI (Gemini 2.0)
class GeminiExpenseParser {
  static GenerativeModel? _model;

  /// Initialize the Gemini model with Firebase AI
  static void initialize() {
    try {
      // Initialize using Firebase AI's Google AI backend with latest stable model
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash', // Latest stable model with JSON support
        generationConfig: GenerationConfig(
          temperature: 0.1, // Low temperature for consistent extraction
          topK: 1,
          topP: 1,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );
      debugPrint(
        '✅ [GeminiParser] Initialized with Gemini 2.5 Flash via Firebase AI',
      );
    } catch (e) {
      debugPrint('❌ [GeminiParser] Failed to initialize: $e');
      _model = null;
    }
  }

  /// Check if Gemini parser is available
  static bool get isAvailable => _model != null;

  /// Parse expense using Gemini AI
  /// Returns a list of ParseResult (can be multiple expenses from one input)
  static Future<List<ParseResult>> parse(
    String input,
    String userId,
    List<QuickCategory> categories,
    String language,
  ) async {
    debugPrint('🤖 [GeminiParser] Parsing input: "$input"');

    if (!isAvailable) {
      debugPrint('⚠️ [GeminiParser] Not available, cannot parse');
      return [];
    }

    // Pre-validate input to avoid meaningless API calls
    if (!_isValidInput(input)) {
      debugPrint(
        '⚠️ [GeminiParser] Input validation failed, skipping API call',
      );
      return [];
    }

    try {
      debugPrint('🔧 [GeminiParser] Building prompt...');
      debugPrint('   Categories: ${categories.length} total');
      debugPrint('   Income: ${categories.where((c) => c.isIncomeCategory).length}');
      debugPrint('   Expense: ${categories.where((c) => c.isExpenseCategory).length}');

      final prompt = _buildPrompt(input, categories, language);

      debugPrint('📏 [GeminiParser] Prompt length: ${prompt.length} characters');
      debugPrint('📝 [GeminiParser] Prompt preview (first 500 chars):');
      debugPrint(prompt.substring(0, prompt.length > 500 ? 500 : prompt.length));
      debugPrint('...');
      debugPrint('📤 [GeminiParser] Sending prompt to Gemini...');
      debugPrint('⏱️ [GeminiParser] Timeout set to ${AppConstants.geminiApiTimeoutSeconds} seconds');

      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(
            Duration(seconds: AppConstants.geminiApiTimeoutSeconds),
            onTimeout: () {
              debugPrint(
                '❌ [GeminiParser] Request timed out after ${AppConstants.geminiApiTimeoutSeconds} seconds',
              );
              debugPrint('💡 [GeminiParser] This might mean:');
              debugPrint('   1. Network connectivity issue');
              debugPrint(
                '   2. Firebase AI API not enabled in your Firebase project',
              );
              debugPrint('   3. API quota exceeded');
              throw TimeoutException('Gemini API request timed out');
            },
          );

      debugPrint('✅ [GeminiParser] Response received from Gemini');

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        debugPrint('❌ [GeminiParser] Empty response from Gemini');
        return [];
      }

      debugPrint('📨 [GeminiParser] Response length: ${responseText.length} characters');
      debugPrint('📨 [GeminiParser] Full response: $responseText');

      // Parse JSON response
      debugPrint('🔍 [GeminiParser] Parsing JSON response...');
      final jsonData = json.decode(responseText) as Map<String, dynamic>;

      debugPrint('🔍 [GeminiParser] JSON decoded successfully');
      final results = _parseResponse(jsonData, userId, input);

      debugPrint('✅ [GeminiParser] Successfully parsed ${results.length} expense(s)');
      return results;
    } catch (e) {
      debugPrint('❌ [GeminiParser] Error parsing: $e');
      return [];
    }
  }

  /// Validate input to avoid meaningless API calls
  /// Filters out empty, too short, or nonsensical voice input
  static bool _isValidInput(String input) {
    // Remove whitespace and check if empty
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      debugPrint('❌ [GeminiParser] Validation: Input is empty');
      return false;
    }

    // Check minimum length
    if (trimmed.length < AppConstants.minVoiceInputLength) {
      debugPrint('❌ [GeminiParser] Validation: Input too short (<${AppConstants.minVoiceInputLength} chars)');
      return false;
    }

    // Must contain at least one alphanumeric character
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
      debugPrint(
        '❌ [GeminiParser] Validation: No alphanumeric characters found',
      );
      return false;
    }

    // Filter out common voice recognition artifacts and filler words
    final meaninglessPatterns = [
      // Single repeated characters: "a a a", "uh uh uh"
      RegExp(r'^([a-z])\s+\1(\s+\1)*$', caseSensitive: false),

      // Common English filler words in isolation
      RegExp(r'^(uh+|um+|ah+|er+|hmm+)$', caseSensitive: false),

      // Common Vietnamese filler words in isolation
      RegExp(r'^(ờ+|à+|ư+|ừ+|ơ+)$', caseSensitive: false),

      // Just punctuation and spaces
      RegExp(r'^[\s\.,;:!?\-]+$'),
    ];

    for (final pattern in meaninglessPatterns) {
      if (pattern.hasMatch(trimmed)) {
        debugPrint('❌ [GeminiParser] Validation: Meaningless pattern detected');
        return false;
      }
    }

    // Check if input is suspiciously repetitive (same word repeated 3+ times)
    final words = trimmed.toLowerCase().split(RegExp(r'\s+'));
    if (words.length >= 3) {
      final uniqueWords = words.toSet();
      if (uniqueWords.length == 1) {
        debugPrint(
          '❌ [GeminiParser] Validation: Suspicious repetition detected',
        );
        return false;
      }
    }

    // Optional: Warn if no numbers found (might still be valid, e.g., "coffee today")
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      debugPrint(
        '⚠️ [GeminiParser] Validation: No numbers found, but allowing (might be description only)',
      );
    }

    debugPrint('✅ [GeminiParser] Validation: Input appears valid');
    return true;
  }

  /// Build the prompt for Gemini with hybrid language approach
  static String _buildPrompt(
    String input,
    List<QuickCategory> categories,
    String language,
  ) {
    // Get current date for Gemini to understand relative dates
    final now = DateTime.now();
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentWeekday = weekdayNames[now.weekday - 1];

    // Build category list with keywords dynamically, grouped by type
    final incomeCategories = categories
        .where((c) => c.isIncomeCategory)
        .toList();
    final expenseCategories = categories
        .where((c) => c.isExpenseCategory)
        .toList();

    final incomeCategoryDesc = incomeCategories
        .map((cat) {
          final keywords = cat.getKeywords(language);
          final label = cat.getLabel(language);
          return '  - ${cat.id}: $label (${keywords.take(2).join(", ")})';
        })
        .join('\n');

    final expenseCategoryDesc = expenseCategories
        .map((cat) {
          final keywords = cat.getKeywords(language);
          final label = cat.getLabel(language);
          return '  - ${cat.id}: $label (${keywords.take(2).join(", ")})';
        })
        .join('\n');

    final categoryDescriptions =
        '''
INCOME Categories:
$incomeCategoryDesc

EXPENSE Categories:
$expenseCategoryDesc''';

    // Build language-specific examples
    final languageHint = language == 'vi'
        ? 'User is speaking in Vietnamese. Expect Vietnamese descriptions and slang.'
        : 'User is speaking in English. Expect English descriptions.';

    final examples = _getLanguageSpecificExamples(language);

    return '''
You are a financial transaction extraction assistant. Extract expense OR income information from user input.

Input: "$input"
Context: $languageHint

**CURRENT DATE CONTEXT:**
- Today is: $currentDate ($currentWeekday)
- Use this to calculate all relative dates accurately

Rules:
1. Extract ALL transactions (can be multiple per input)
2. Classify as EXPENSE or INCOME (keywords: "received/nhận/lương" = income, "spent/chi/mua" = expense, default = expense)
3. Parse amounts: "50k"=50000, "1m5"=1500000, Vietnamese slang "ca"=thousand, "củ/cọc"=million
4. Parse dates: Use CURRENT DATE CONTEXT to calculate "yesterday", "last monday", "3 days ago", etc. Return YYYY-MM-DD format only
5. Categorize using categories below (match keywords, fallback to "other" or "other_income")
6. Fix voice errors: "tiền cơ"→"tiền cơm", "xă"→"xăng"
7. Multiple transactions: "50k coffee and 30k parking" = 2 separate expenses

Categories:
$categoryDescriptions

Return JSON in this EXACT format:
{
  "language": "en" or "vi",
  "expenses": [
    {
      "amount": number (in base units, e.g., 50000 not 50k),
      "description": "clear description",
      "category": "category name from the list above",
      "type": "expense" or "income",
      "date": "YYYY-MM-DD" or "today" or "yesterday" or relative date,
      "confidence": number between 0 and 1
    }
  ]
}

$examples

Now extract from the input above. Return ONLY valid JSON, no other text.
''';
  }

  /// Get language-specific examples based on detected language
  static String _getLanguageSpecificExamples(String language) {
    if (language == 'vi') {
      return '''
Examples:
"45 ca tiền cơm" → {"language":"vi","expenses":[{"amount":45000,"description":"tiền cơm","category":"food","type":"expense","date":"today","confidence":0.95}]}
"nhận lương 15 triệu" → {"language":"vi","expenses":[{"amount":15000000,"description":"lương","category":"salary","type":"income","date":"today","confidence":0.95}]}
"100k xăng và 30k cafe" → {"language":"vi","expenses":[{"amount":100000,"description":"xăng","category":"transport","type":"expense","date":"today","confidence":0.95},{"amount":30000,"description":"cà phê","category":"food","type":"expense","date":"today","confidence":0.95}]}
"50k cafe thứ 6 tuần trước" (today is 2025-01-13) → {"language":"vi","expenses":[{"amount":50000,"description":"cà phê","category":"food","type":"expense","date":"2025-01-10","confidence":0.95}]}
''';
    } else {
      return '''
Examples:
"50k coffee" → {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","type":"expense","date":"today","confidence":0.95}]}
"received salary 1.5 million" → {"language":"en","expenses":[{"amount":1500000,"description":"salary","category":"salary","type":"income","date":"today","confidence":0.95}]}
"50k coffee and 30k parking" → {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","type":"expense","date":"today","confidence":0.95},{"amount":30000,"description":"parking","category":"transport","type":"expense","date":"today","confidence":0.95}]}
"100k gas last monday" (today is 2025-01-13) → {"language":"en","expenses":[{"amount":100000,"description":"gas","category":"transport","type":"expense","date":"2025-01-06","confidence":0.95}]}
''';
    }
  }

  /// Parse Gemini response into ParseResult objects
  static List<ParseResult> _parseResponse(
    Map<String, dynamic> jsonData,
    String userId,
    String rawInput,
  ) {
    final results = <ParseResult>[];

    try {
      final language = jsonData['language'] as String? ?? 'en';
      final expenses = jsonData['expenses'] as List<dynamic>? ?? [];

      debugPrint(
        '📊 [GeminiParser] Language: $language, Expenses: ${expenses.length}',
      );

      int itemIndex = 0;
      for (final expenseData in expenses) {
        itemIndex++;
        debugPrint('🔄 [GeminiParser] Processing item $itemIndex/${expenses.length}...');
        try {
          final expenseMap = expenseData as Map<String, dynamic>;

          final amount = (expenseMap['amount'] as num?)?.toDouble() ?? 0.0;
          final description = expenseMap['description'] as String? ?? '';
          final categoryStr = expenseMap['category'] as String? ?? 'other';
          final typeStr = expenseMap['type'] as String? ?? 'expense';
          final dateStr = expenseMap['date'] as String? ?? 'today';
          final confidence =
              (expenseMap['confidence'] as num?)?.toDouble() ?? 0.5;

          debugPrint('   Raw data: amount=$amount, desc="$description", category="$categoryStr", type="$typeStr"');

          // Validate amount
          if (amount <= 0) {
            debugPrint('⚠️ [GeminiParser] Invalid amount: $amount, skipping');
            continue;
          }

          // Parse transaction type
          debugPrint('   Parsing type: "$typeStr"');
          final transactionType = TransactionType.fromJson(typeStr);

          // Normalize category string to lowercase ID
          debugPrint('   Normalizing category: "$categoryStr" → processing...');
          final categoryId = _normalizeCategoryId(categoryStr, transactionType);
          debugPrint('   Normalized category: "$categoryId"');

          // Ensure type matches category (fix inconsistencies from Gemini)
          final correctedType = _getTypeFromCategory(categoryId);
          debugPrint('   Type check: Gemini="$typeStr" (${transactionType.name}), Category expects=${correctedType.name}');
          if (correctedType != transactionType) {
            debugPrint(
              '⚠️ [GeminiParser] Type mismatch: Gemini said "$typeStr" but category "$categoryId" is ${correctedType.name}. Using category type.',
            );
          }

          // Parse date from relative or absolute format
          final parsedDate = _parseDate(dateStr);
          debugPrint(
            '📅 [GeminiParser] Date: "$dateStr" → ${parsedDate.toIso8601String()}',
          );

          // Create expense object
          final expense = Expense(
            id: const Uuid().v4(),
            amount: amount,
            description: description.isEmpty
                ? (correctedType == TransactionType.income
                      ? 'Income'
                      : 'Expense')
                : description,
            categoryId: categoryId,
            language: language,
            date: parsedDate,
            userId: userId,
            rawInput: rawInput,
            confidence: confidence,
            type: correctedType, // Use corrected type based on category
          );

          results.add(
            ParseResult(
              success: true,
              expense: expense,
              language: language,
              languageConfidence:
                  0.95, // Gemini is very good at language detection
              categoryConfidence: confidence,
              overallConfidence: confidence,
            ),
          );

          debugPrint(
            '✅ [GeminiParser] Parsed: ${expense.type.name.toUpperCase()} ${expense.amount} - ${expense.description} (${expense.categoryId}) on ${parsedDate.toIso8601String().split('T')[0]}',
          );
        } catch (e) {
          debugPrint('❌ [GeminiParser] Error parsing expense item: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [GeminiParser] Error parsing response structure: $e');
    }

    return results;
  }

  /// Parse date from string (supports relative and absolute dates)
  static DateTime _parseDate(String dateStr) {
    final now = DateTime.now();
    final normalized = dateStr.toLowerCase().trim();

    // Handle relative dates (English)
    if (normalized == 'today' || normalized == 'hôm nay') {
      return DateTime(now.year, now.month, now.day);
    }
    if (normalized == 'yesterday' || normalized == 'hôm qua') {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTime(yesterday.year, yesterday.month, yesterday.day);
    }
    if (normalized == 'last week' || normalized == 'tuần trước') {
      final lastWeek = now.subtract(const Duration(days: 7));
      return DateTime(lastWeek.year, lastWeek.month, lastWeek.day);
    }
    if (normalized == 'last month' || normalized == 'tháng trước') {
      final lastMonth = DateTime(now.year, now.month - 1, now.day);
      return DateTime(lastMonth.year, lastMonth.month, lastMonth.day);
    }

    // Handle "X days ago" / "X ngày trước"
    final daysAgoMatch = RegExp(
      r'(\d+)\s*(days?|ngày)\s*(ago|trước)',
    ).firstMatch(normalized);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1) ?? '0') ?? 0;
      final date = now.subtract(Duration(days: days));
      return DateTime(date.year, date.month, date.day);
    }

    // Handle "X weeks ago" / "X tuần trước"
    final weeksAgoMatch = RegExp(
      r'(\d+)\s*(weeks?|tuần)\s*(ago|trước)',
    ).firstMatch(normalized);
    if (weeksAgoMatch != null) {
      final weeks = int.tryParse(weeksAgoMatch.group(1) ?? '0') ?? 0;
      final date = now.subtract(Duration(days: weeks * 7));
      return DateTime(date.year, date.month, date.day);
    }

    // Handle day-specific dates like "friday last week", "last monday", "this tuesday"
    // This is a fallback in case Gemini doesn't calculate the exact date
    final dayNames = {
      'monday': 1, 'mon': 1,
      'tuesday': 2, 'tue': 2, 'tues': 2,
      'wednesday': 3, 'wed': 3,
      'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4,
      'friday': 5, 'fri': 5,
      'saturday': 6, 'sat': 6,
      'sunday': 7, 'sun': 7,
    };

    // Pattern: "friday last week" or "last friday"
    for (final entry in dayNames.entries) {
      final dayName = entry.key;
      final targetWeekday = entry.value;

      if (normalized.contains(dayName)) {
        if (normalized.contains('last') || normalized.contains('trước')) {
          // Find the last occurrence of this weekday
          var daysBack = now.weekday - targetWeekday;
          if (daysBack <= 0) daysBack += 7; // Go to previous week
          final date = now.subtract(Duration(days: daysBack));
          debugPrint(
            '📅 [GeminiParser] Parsed "$dateStr" as last $dayName: ${date.toIso8601String().split('T')[0]}',
          );
          return DateTime(date.year, date.month, date.day);
        }
      }
    }

    // Try parsing absolute dates (ISO format: YYYY-MM-DD)
    try {
      final parsed = DateTime.parse(dateStr);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      // Ignore and continue
    }

    // Try common formats: MM/DD, DD/MM, MM-DD, DD-MM
    final datePattern = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?');
    final match = datePattern.firstMatch(normalized);
    if (match != null) {
      try {
        final part1 = int.parse(match.group(1)!);
        final part2 = int.parse(match.group(2)!);
        final yearStr = match.group(3);
        final year = yearStr != null
            ? (int.parse(yearStr) + (yearStr.length == 2 ? 2000 : 0))
            : now.year;

        // Assume MM/DD format (US style) if first part > 12, otherwise DD/MM
        if (part1 > 12) {
          return DateTime(year, part2, part1); // DD/MM
        } else if (part2 > 12) {
          return DateTime(year, part1, part2); // MM/DD
        } else {
          // Ambiguous - default to MM/DD
          return DateTime(year, part1, part2);
        }
      } catch (_) {
        // Ignore and return today
      }
    }

    // Default to today if parsing fails
    debugPrint(
      '⚠️ [GeminiParser] Could not parse date "$dateStr", using today',
    );
    return DateTime(now.year, now.month, now.day);
  }

  /// Normalize category string to category ID
  static String _normalizeCategoryId(String categoryStr, TransactionType type) {
    final normalized = categoryStr.toLowerCase().trim();

    // Map to known system category IDs
    const expenseCategories = {
      'food',
      'transport',
      'shopping',
      'bills',
      'health',
      'entertainment',
      'other',
    };

    const incomeCategories = {
      'salary',
      'freelance',
      'investment',
      'gift_received',
      'refund',
      'other_income',
    };

    if (type == TransactionType.income) {
      return incomeCategories.contains(normalized)
          ? normalized
          : 'other_income';
    } else {
      return expenseCategories.contains(normalized) ? normalized : 'other';
    }
  }

  /// Get the correct transaction type based on category ID
  /// This ensures type consistency regardless of what Gemini returns
  static TransactionType _getTypeFromCategory(String categoryId) {
    const incomeCategories = {
      'salary',
      'freelance',
      'investment',
      'gift_received',
      'refund',
      'other_income',
    };

    return incomeCategories.contains(categoryId)
        ? TransactionType.income
        : TransactionType.expense;
  }
}

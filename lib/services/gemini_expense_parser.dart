import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'expense_parser.dart';

/// AI-powered expense parser using Firebase AI (Gemini 2.0)
class GeminiExpenseParser {
  static GenerativeModel? _model;
  static const int _apiTimeout = 30; // seconds - increased for first request

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
      debugPrint('✅ [GeminiParser] Initialized with Gemini 2.5 Flash via Firebase AI');
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
      debugPrint('⚠️ [GeminiParser] Input validation failed, skipping API call');
      return [];
    }

    try {
      final prompt = _buildPrompt(input, categories, language);
      debugPrint('📝 [GeminiParser] Sending prompt to Gemini...');
      debugPrint('⏱️ [GeminiParser] Timeout set to $_apiTimeout seconds');

      final response = await _model!
          .generateContent([Content.text(prompt)])
          .timeout(
            Duration(seconds: _apiTimeout),
            onTimeout: () {
              debugPrint('❌ [GeminiParser] Request timed out after $_apiTimeout seconds');
              debugPrint('💡 [GeminiParser] This might mean:');
              debugPrint('   1. Network connectivity issue');
              debugPrint('   2. Firebase AI API not enabled in your Firebase project');
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

      debugPrint('📨 [GeminiParser] Response text: $responseText');

      // Parse JSON response
      final jsonData = json.decode(responseText) as Map<String, dynamic>;
      final results = _parseResponse(jsonData, userId, input);

      debugPrint('✅ [GeminiParser] Parsed ${results.length} expense(s)');
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

    // Check minimum length (at least 2 characters)
    if (trimmed.length < 2) {
      debugPrint('❌ [GeminiParser] Validation: Input too short (<2 chars)');
      return false;
    }

    // Must contain at least one alphanumeric character
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) {
      debugPrint('❌ [GeminiParser] Validation: No alphanumeric characters found');
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
        debugPrint('❌ [GeminiParser] Validation: Suspicious repetition detected');
        return false;
      }
    }

    // Optional: Warn if no numbers found (might still be valid, e.g., "coffee today")
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      debugPrint('⚠️ [GeminiParser] Validation: No numbers found, but allowing (might be description only)');
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
    // Build category list with keywords dynamically
    final categoryDescriptions = categories.map((cat) {
      final keywords = cat.getKeywords(language);
      final label = cat.getLabel(language);
      return '- ${cat.id}: $label (${keywords.take(5).join(", ")}, etc.)';
    }).join('\n');

    // Get all category IDs for the rule
    final categoryIds = categories.map((c) => c.id).join(', ');

    // Build language-specific examples
    final languageHint = language == 'vi'
        ? 'User is speaking in Vietnamese. Expect Vietnamese descriptions and slang.'
        : 'User is speaking in English. Expect English descriptions.';

    final examples = _getLanguageSpecificExamples(language);

    return '''
You are an expense extraction assistant. Extract expense information from user input.

Input: "$input"
Context: $languageHint

Rules:
1. Extract ALL expenses mentioned (there can be multiple in one input)
2. Detect language (en or vi) - use context hint above
3. Parse amounts in various formats:
   - Standard: "50k" = 50000, "1.5m" or "1m5" = 1500000
   - Vietnamese: "50 nghìn" = 50000, "1 triệu" = 1000000
   - Plain numbers: 50000, 1500000
   - **Vietnamese slang** (CRITICAL - very common in speech):
     * "ca" = thousand (k): "45 ca" = 45000, "100ca" = 100000
     * "củ" = million: "1 củ" = 1000000, "1.5 củ" = 1500000, "2cu" = 2000000
     * "cọc" = million: "1 cọc" = 1000000, "3 cọc" = 3000000
     * "chai" = hundred: "5 chai" = 500 (less common)
   - Important: "củ" and "cọc" mean MILLION, not thousand!
4. Parse dates and temporal references:
   - Absolute: "on December 5", "12/5", "2024-12-05"
   - Relative: "yesterday", "hôm qua", "last week", "tuần trước", "3 days ago", "3 ngày trước"
   - Default: If no date mentioned, use "today"
5. Categorize into: $categoryIds
6. Fix incomplete words from voice recognition:
   - Vietnamese: "tiền cơ" → "tiền cơm", "xă" → "xăng", "cafe" can be "cà phê" or "cafe"
   - Keep original if unclear
7. Handle complex sentences:
   - Multiple items: "vegetables, meat, and rice for 200k" → one expense, 200k total
   - Multiple expenses: "50k coffee and 30k parking" → two separate expenses
   - Temporal sequences: "yesterday 50k coffee, today 30k parking" → two expenses with different dates

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
Examples (Vietnamese):

Input: "45 ca tiền cơm"
Output: {"language":"vi","expenses":[{"amount":45000,"description":"tiền cơm","category":"food","date":"today","confidence":0.95}]}

Input: "1 củ xăng hôm qua"
Output: {"language":"vi","expenses":[{"amount":1000000,"description":"xăng","category":"transport","date":"yesterday","confidence":0.95}]}

Input: "100k xăng và 30k cafe"
Output: {"language":"vi","expenses":[{"amount":100000,"description":"xăng","category":"transport","date":"today","confidence":0.95},{"amount":30000,"description":"cà phê","category":"food","date":"today","confidence":0.95}]}

Input: "2 củ mua rau củ thịt cá ở chợ"
Output: {"language":"vi","expenses":[{"amount":2000000,"description":"rau củ thịt cá","category":"shopping","date":"today","confidence":0.90}]}

Input: "tiền điện 500k tuần trước"
Output: {"language":"vi","expenses":[{"amount":500000,"description":"tiền điện","category":"bills","date":"last week","confidence":0.95}]}

Input: "hôm qua 50ca cafe, hôm nay 30ca đỗ xe"
Output: {"language":"vi","expenses":[{"amount":50000,"description":"cà phê","category":"food","date":"yesterday","confidence":0.90},{"amount":30000,"description":"đỗ xe","category":"transport","date":"today","confidence":0.90}]}

Input: "1.5 củ shopping"
Output: {"language":"vi","expenses":[{"amount":1500000,"description":"shopping","category":"shopping","date":"today","confidence":0.95}]}
''';
    } else {
      return '''
Examples (English):

Input: "50k coffee"
Output: {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","date":"today","confidence":0.95}]}

Input: "100k gas yesterday"
Output: {"language":"en","expenses":[{"amount":100000,"description":"gas","category":"transport","date":"yesterday","confidence":0.95}]}

Input: "50k coffee and 30k parking"
Output: {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","date":"today","confidence":0.95},{"amount":30000,"description":"parking","category":"transport","date":"today","confidence":0.95}]}

Input: "bought groceries for 200k including vegetables and meat"
Output: {"language":"en","expenses":[{"amount":200000,"description":"groceries (vegetables and meat)","category":"shopping","date":"today","confidence":0.90}]}

Input: "electricity bill 500k last week"
Output: {"language":"en","expenses":[{"amount":500000,"description":"electricity bill","category":"bills","date":"last week","confidence":0.95}]}

Input: "yesterday 50k coffee, today 30k parking"
Output: {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","date":"yesterday","confidence":0.90},{"amount":30000,"description":"parking","category":"transport","date":"today","confidence":0.90}]}
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

      for (final expenseData in expenses) {
        try {
          final expenseMap = expenseData as Map<String, dynamic>;

          final amount = (expenseMap['amount'] as num?)?.toDouble() ?? 0.0;
          final description = expenseMap['description'] as String? ?? '';
          final categoryStr = expenseMap['category'] as String? ?? 'other';
          final dateStr = expenseMap['date'] as String? ?? 'today';
          final confidence =
              (expenseMap['confidence'] as num?)?.toDouble() ?? 0.5;

          // Validate amount
          if (amount <= 0) {
            debugPrint('⚠️ [GeminiParser] Invalid amount: $amount, skipping');
            continue;
          }

          // Normalize category string to lowercase ID
          final categoryId = _normalizeCategoryId(categoryStr);

          // Parse date from relative or absolute format
          final parsedDate = _parseDate(dateStr);
          debugPrint(
            '📅 [GeminiParser] Date string: "$dateStr" → ${parsedDate.toIso8601String()}',
          );

          // Create expense object
          final expense = Expense(
            id: const Uuid().v4(),
            amount: amount,
            description: description.isEmpty ? 'Expense' : description,
            categoryId: categoryId,
            language: language,
            date: parsedDate,
            userId: userId,
            rawInput: rawInput,
            confidence: confidence,
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
            '✅ [GeminiParser] Parsed: ${expense.amount} - ${expense.description} (${expense.categoryId}) on ${parsedDate.toIso8601String().split('T')[0]}',
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
    final daysAgoMatch = RegExp(r'(\d+)\s*(days?|ngày)\s*(ago|trước)')
        .firstMatch(normalized);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1) ?? '0') ?? 0;
      final date = now.subtract(Duration(days: days));
      return DateTime(date.year, date.month, date.day);
    }

    // Handle "X weeks ago" / "X tuần trước"
    final weeksAgoMatch = RegExp(r'(\d+)\s*(weeks?|tuần)\s*(ago|trước)')
        .firstMatch(normalized);
    if (weeksAgoMatch != null) {
      final weeks = int.tryParse(weeksAgoMatch.group(1) ?? '0') ?? 0;
      final date = now.subtract(Duration(days: weeks * 7));
      return DateTime(date.year, date.month, date.day);
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
    debugPrint('⚠️ [GeminiParser] Could not parse date "$dateStr", using today');
    return DateTime(now.year, now.month, now.day);
  }

  /// Normalize category string to category ID
  static String _normalizeCategoryId(String categoryStr) {
    final normalized = categoryStr.toLowerCase().trim();
    // Map to known system category IDs
    const validCategories = {
      'food',
      'transport',
      'shopping',
      'bills',
      'health',
      'entertainment',
      'other',
    };

    return validCategories.contains(normalized) ? normalized : 'other';
  }
}

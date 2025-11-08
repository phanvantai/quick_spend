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

  /// Build the prompt for Gemini
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

    return '''
You are an expense extraction assistant. Extract expense information from user input.

Input: "$input"

Rules:
1. Extract ALL expenses mentioned (there can be multiple)
2. Detect language (en or vi)
3. Parse amounts in various formats:
   - "50k" = 50000
   - "1.5m" or "1m5" = 1500000
   - "50 nghìn" = 50000
   - "1 triệu" = 1000000
   - Plain numbers
   - **Vietnamese slang** (VERY IMPORTANT - commonly used):
     - "45 ca" or "45ca" = 45000 (ca = k = thousand)
     - "1 củ" or "1cu" = 1000000 (củ = million, NOT thousand)
     - "1.5 củ" = 1500000
     - "1 cọc" or "1coc" = 1000000 (cọc = million)
     - Listen for "ca", "củ", "cọc" and convert properly
4. Categorize into: $categoryIds
5. Extract clear descriptions (e.g., "tiền cơ" should be "tiền cơm" for food)

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
      "confidence": number between 0 and 1
    }
  ]
}

Examples:
Input: "50k coffee"
Output: {"language":"en","expenses":[{"amount":50000,"description":"coffee","category":"food","confidence":0.95}]}

Input: "100k xăng and 30k cafe"
Output: {"language":"vi","expenses":[{"amount":100000,"description":"xăng","category":"transport","confidence":0.95},{"amount":30000,"description":"cafe","category":"food","confidence":0.95}]}

Input: "45 ca tiền cơm"
Output: {"language":"vi","expenses":[{"amount":45000,"description":"tiền cơm","category":"food","confidence":0.90}]}

Input: "1 củ xăng"
Output: {"language":"vi","expenses":[{"amount":1000000,"description":"xăng","category":"transport","confidence":0.95}]}

Input: "1.5 củ shopping"
Output: {"language":"vi","expenses":[{"amount":1500000,"description":"shopping","category":"shopping","confidence":0.95}]}

Now extract from the input above. Return ONLY valid JSON, no other text.
''';
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
          final confidence =
              (expenseMap['confidence'] as num?)?.toDouble() ?? 0.5;

          // Validate amount
          if (amount <= 0) {
            debugPrint('⚠️ [GeminiParser] Invalid amount: $amount, skipping');
            continue;
          }

          // Normalize category string to lowercase ID
          final categoryId = _normalizeCategoryId(categoryStr);

          // Create expense object
          final expense = Expense(
            id: const Uuid().v4(),
            amount: amount,
            description: description.isEmpty ? 'Expense' : description,
            categoryId: categoryId,
            language: language,
            date: DateTime.now(),
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
            '✅ [GeminiParser] Parsed: ${expense.amount} - ${expense.description} (${expense.category})',
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

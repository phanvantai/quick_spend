import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'amount_parser.dart';
import 'categorizer.dart';
import 'gemini_expense_parser.dart';
import 'gemini_usage_limit_service.dart';
import 'analytics_service.dart';

/// Main expense parser that orchestrates language detection,
/// amount extraction, and auto-categorization
/// Now uses Gemini AI as primary parser with fallback to rule-based parser
class ExpenseParser {
  static const _uuid = Uuid();

  /// Parse raw input string into a structured Expense object
  /// Uses Gemini AI if available, falls back to rule-based parser
  /// Returns ParseResult with the expense and metadata
  /// [language] should be the user's app language (e.g., 'en', 'vi', 'ja', 'ko', 'th', 'es')
  static Future<List<ParseResult>> parse(
    String rawInput,
    String userId,
    List<QuickCategory> categories, {
    String? language,
    GeminiUsageLimitService? usageLimitService,
    AnalyticsService? analyticsService,
  }) async {
    debugPrint('💸 [ExpenseParser] Starting parse for: "$rawInput"');

    // Use provided language or default to English
    final effectiveLanguage = language ?? 'en';
    debugPrint('🌍 [ExpenseParser] Language: $effectiveLanguage');

    // Try Gemini parser first if available
    if (GeminiExpenseParser.isAvailable) {
      debugPrint('🤖 [ExpenseParser] Using Gemini AI parser');
      try {
        final geminiResults = await GeminiExpenseParser.parse(
          rawInput,
          userId,
          categories,
          effectiveLanguage,
          usageLimitService,
        );
        if (geminiResults.isNotEmpty) {
          // Check if it's a limit reached error
          if (geminiResults.first.errorMessage == 'GEMINI_LIMIT_REACHED') {
            debugPrint('⛔ [ExpenseParser] Gemini limit reached, returning error to user');
            // Log limit reached event
            analyticsService?.logGeminiLimitReached(remainingCount: 0);
            return geminiResults; // Return the error, don't fall back
          }
          debugPrint('✅ [ExpenseParser] Gemini returned ${geminiResults.length} result(s)');

          // Log successful Gemini parse
          for (final result in geminiResults) {
            if (result.success && result.expense != null) {
              analyticsService?.logGeminiParseSuccess(
                confidence: result.overallConfidence ?? 0.9,
                expenseCount: geminiResults.length,
                language: result.language ?? effectiveLanguage,
              );
            }
          }

          return geminiResults;
        }
        debugPrint('⚠️ [ExpenseParser] Gemini returned no results, falling back to rule-based');

        // Log fallback due to no results
        analyticsService?.logFallbackParserUsed(
          reason: 'gemini_failed',
          language: effectiveLanguage,
        );
      } catch (e) {
        debugPrint('⚠️ [ExpenseParser] Gemini failed: $e, falling back to rule-based');

        // Log fallback due to error
        analyticsService?.logGeminiParseFailed(
          errorReason: e.toString().substring(0, 100), // Limit error message length
          language: effectiveLanguage,
        );
        analyticsService?.logFallbackParserUsed(
          reason: 'gemini_failed',
          language: effectiveLanguage,
        );
      }
    } else {
      debugPrint('📋 [ExpenseParser] Gemini not available, using rule-based parser');

      // Log fallback due to Gemini unavailable
      analyticsService?.logFallbackParserUsed(
        reason: 'gemini_unavailable',
        language: effectiveLanguage,
      );
    }

    // Fallback to rule-based parser
    final result = _parseRuleBased(rawInput, userId, categories, effectiveLanguage);
    return [result];
  }

  /// Original rule-based parsing (kept as fallback)
  static ParseResult _parseRuleBased(
    String rawInput,
    String userId,
    List<QuickCategory> categories,
    String language,
  ) {
    debugPrint('💸 [ExpenseParser] Parsing input: "$rawInput"');

    // Validate input
    if (rawInput.trim().isEmpty) {
      debugPrint('❌ [ExpenseParser] Empty input');
      return ParseResult(
        success: false,
        errorMessage: 'Input cannot be empty',
        parserUsed: 'fallback',
      );
    }

    final trimmedInput = rawInput.trim();

    // Step 1: Use provided language (already determined by user's app settings)
    debugPrint('🌍 [ExpenseParser] Using language: $language');
    const languageConfidence = 1.0; // User's explicit language choice

    // Step 2: Extract amount and description
    final amountResult = AmountParser.extractAmount(trimmedInput);
    debugPrint('💰 [ExpenseParser] Extracting amount from: "$trimmedInput"');

    if (amountResult == null) {
      debugPrint('❌ [ExpenseParser] Could not extract amount');
      return ParseResult(
        success: false,
        errorMessage: 'Could not find a valid amount in the input',
        parserUsed: 'fallback',
      );
    }

    debugPrint('   Amount: ${amountResult.amount} (raw: "${amountResult.rawAmount}")');
    debugPrint('   Remaining text: "${amountResult.description}"');

    // Validate amount
    if (amountResult.amount <= 0) {
      debugPrint('❌ [ExpenseParser] Invalid amount: ${amountResult.amount}');
      return ParseResult(
        success: false,
        errorMessage: 'Amount must be greater than zero',
        parserUsed: 'fallback',
      );
    }

    // Step 3: Get description (cleaned)
    String description = amountResult.description.trim();

    // Step 3.5: Detect transaction type (income or expense)
    final transactionType = Categorizer.detectTransactionType(description, language);
    debugPrint('💡 [ExpenseParser] Transaction type: ${transactionType.name}');

    if (description.isEmpty) {
      // Use a default description based on language and type
      if (transactionType == TransactionType.income) {
        description = language == 'vi' ? 'Thu nhập' : 'Income';
      } else {
        description = language == 'vi' ? 'Chi tiêu' : 'Expense';
      }
      debugPrint('📝 [ExpenseParser] Using default description: "$description"');
    } else {
      debugPrint('📝 [ExpenseParser] Description: "$description"');
    }

    // Step 4: Auto-categorize based on description
    final categoryResult = Categorizer.categorize(
      description,
      categories,
      type: transactionType,
    );
    debugPrint('🏷️ [ExpenseParser] Category: ${categoryResult.categoryId} (confidence: ${(categoryResult.confidence * 100).toStringAsFixed(1)}%)');

    // Ensure type matches category (fix inconsistencies)
    final correctedType = _getTypeFromCategory(categoryResult.categoryId);
    if (correctedType != transactionType) {
      debugPrint('⚠️ [ExpenseParser] Type mismatch: detected "$transactionType" but category "${categoryResult.categoryId}" is ${correctedType.name}. Using category type.');
    }

    // Calculate overall confidence
    // Weight: 50% categorization, 30% language detection, 20% amount parsing
    final overallConfidence = (categoryResult.confidence * 0.5) +
        (languageConfidence * 0.3) +
        (0.2); // Amount parsing is assumed successful if we got here

    debugPrint('📊 [ExpenseParser] Overall confidence: ${(overallConfidence * 100).toStringAsFixed(1)}%');

    // Step 5: Create Expense object
    final expense = Expense(
      id: _uuid.v4(),
      amount: amountResult.amount,
      description: description,
      categoryId: categoryResult.categoryId,
      language: language,
      date: DateTime.now(),
      userId: userId,
      rawInput: rawInput,
      confidence: overallConfidence,
      type: correctedType, // Use corrected type based on category
    );

    debugPrint('✅ [ExpenseParser] Success! Parsed expense with ID: ${expense.id}');

    return ParseResult(
      success: true,
      expense: expense,
      language: language,
      languageConfidence: languageConfidence,
      categoryConfidence: categoryResult.confidence,
      overallConfidence: overallConfidence,
      suggestedCategories: Categorizer.getAllMatches(
        description,
        categories,
        type: transactionType,
      ),
      parserUsed: 'fallback',
    );
  }

  /// Parse with custom category (user override)
  static Future<List<ParseResult>> parseWithCategory(
    String rawInput,
    String userId,
    List<QuickCategory> categories,
    String categoryId, {
    String? language,
    GeminiUsageLimitService? usageLimitService,
    AnalyticsService? analyticsService,
  }) async {
    final results = await parse(
      rawInput,
      userId,
      categories,
      language: language,
      usageLimitService: usageLimitService,
      analyticsService: analyticsService,
    );

    if (results.isEmpty) {
      return [
        ParseResult(
          success: false,
          errorMessage: 'Failed to parse expense',
        )
      ];
    }

    // Override category for all parsed expenses
    final updatedResults = <ParseResult>[];
    for (final result in results) {
      if (!result.success || result.expense == null) {
        updatedResults.add(result);
        continue;
      }

      // Override category with user's choice
      final updatedExpense = result.expense!.copyWith(
        categoryId: categoryId,
        confidence: 1.0, // User confirmed, so confidence is 100%
      );

      updatedResults.add(ParseResult(
        success: true,
        expense: updatedExpense,
        language: result.language,
        languageConfidence: result.languageConfidence,
        categoryConfidence: 1.0, // User confirmed
        overallConfidence: 1.0,
        suggestedCategories: result.suggestedCategories,
      ));
    }

    return updatedResults;
  }

  /// Get the correct transaction type based on category ID
  /// This ensures type consistency
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

/// Result of parsing operation
class ParseResult {
  final bool success;
  final Expense? expense;
  final String? errorMessage;
  final String? language;
  final double? languageConfidence;
  final double? categoryConfidence;
  final double? overallConfidence;
  final List<CategoryResult>? suggestedCategories;
  final String? parserUsed; // 'gemini' or 'fallback'

  ParseResult({
    required this.success,
    this.expense,
    this.errorMessage,
    this.language,
    this.languageConfidence,
    this.categoryConfidence,
    this.overallConfidence,
    this.suggestedCategories,
    this.parserUsed,
  });

  @override
  String toString() {
    if (!success) {
      return 'ParseResult(success: false, error: $errorMessage)';
    }
    return 'ParseResult(success: true, expense: $expense, confidence: $overallConfidence)';
  }
}

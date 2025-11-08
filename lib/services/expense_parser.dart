import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'amount_parser.dart';
import 'language_detector.dart';
import 'categorizer.dart';
import 'gemini_expense_parser.dart';

/// Main expense parser that orchestrates language detection,
/// amount extraction, and auto-categorization
/// Now uses Gemini AI as primary parser with fallback to rule-based parser
class ExpenseParser {
  static const _uuid = Uuid();

  /// Parse raw input string into a structured Expense object
  /// Uses Gemini AI if available, falls back to rule-based parser
  /// Returns ParseResult with the expense and metadata
  static Future<List<ParseResult>> parse(
    String rawInput,
    String userId,
    List<QuickCategory> categories,
  ) async {
    debugPrint('💸 [ExpenseParser] Starting parse for: "$rawInput"');

    // Try Gemini parser first if available
    if (GeminiExpenseParser.isAvailable) {
      debugPrint('🤖 [ExpenseParser] Using Gemini AI parser');
      try {
        final geminiResults = await GeminiExpenseParser.parse(rawInput, userId);
        if (geminiResults.isNotEmpty) {
          debugPrint('✅ [ExpenseParser] Gemini returned ${geminiResults.length} result(s)');
          return geminiResults;
        }
        debugPrint('⚠️ [ExpenseParser] Gemini returned no results, falling back to rule-based');
      } catch (e) {
        debugPrint('⚠️ [ExpenseParser] Gemini failed: $e, falling back to rule-based');
      }
    } else {
      debugPrint('📋 [ExpenseParser] Gemini not available, using rule-based parser');
    }

    // Fallback to rule-based parser
    final result = _parseRuleBased(rawInput, userId, categories);
    return [result];
  }

  /// Original rule-based parsing (kept as fallback)
  static ParseResult _parseRuleBased(
    String rawInput,
    String userId,
    List<QuickCategory> categories,
  ) {
    debugPrint('💸 [ExpenseParser] Parsing input: "$rawInput"');

    // Validate input
    if (rawInput.trim().isEmpty) {
      debugPrint('❌ [ExpenseParser] Empty input');
      return ParseResult(
        success: false,
        errorMessage: 'Input cannot be empty',
      );
    }

    final trimmedInput = rawInput.trim();

    // Step 1: Detect language
    final language = LanguageDetector.detectLanguage(trimmedInput);
    final languageConfidence =
        LanguageDetector.getConfidence(trimmedInput, language);
    debugPrint('🌍 [ExpenseParser] Language: $language (confidence: ${(languageConfidence * 100).toStringAsFixed(1)}%)');

    // Step 2: Extract amount and description
    final amountResult = AmountParser.extractAmount(trimmedInput);
    debugPrint('💰 [ExpenseParser] Extracting amount from: "$trimmedInput"');

    if (amountResult == null) {
      debugPrint('❌ [ExpenseParser] Could not extract amount');
      return ParseResult(
        success: false,
        errorMessage: 'Could not find a valid amount in the input',
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
      );
    }

    // Step 3: Get description (cleaned)
    String description = amountResult.description.trim();
    if (description.isEmpty) {
      // Use a default description based on language
      description = language == 'vi' ? 'Chi tiêu' : 'Expense';
      debugPrint('📝 [ExpenseParser] Using default description: "$description"');
    } else {
      debugPrint('📝 [ExpenseParser] Description: "$description"');
    }

    // Step 4: Auto-categorize based on description
    final categoryResult = Categorizer.categorize(description, language, categories);
    debugPrint('🏷️ [ExpenseParser] Category: ${categoryResult.categoryId} (confidence: ${(categoryResult.confidence * 100).toStringAsFixed(1)}%)');

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
    );

    debugPrint('✅ [ExpenseParser] Success! Parsed expense with ID: ${expense.id}');

    return ParseResult(
      success: true,
      expense: expense,
      language: language,
      languageConfidence: languageConfidence,
      categoryConfidence: categoryResult.confidence,
      overallConfidence: overallConfidence,
      suggestedCategories: Categorizer.getAllMatches(description, language, categories),
    );
  }

  /// Parse with custom category (user override)
  static Future<List<ParseResult>> parseWithCategory(
    String rawInput,
    String userId,
    List<QuickCategory> categories,
    String categoryId,
  ) async {
    final results = await parse(rawInput, userId, categories);

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

  ParseResult({
    required this.success,
    this.expense,
    this.errorMessage,
    this.language,
    this.languageConfidence,
    this.categoryConfidence,
    this.overallConfidence,
    this.suggestedCategories,
  });

  @override
  String toString() {
    if (!success) {
      return 'ParseResult(success: false, error: $errorMessage)';
    }
    return 'ParseResult(success: true, expense: $expense, confidence: $overallConfidence)';
  }
}

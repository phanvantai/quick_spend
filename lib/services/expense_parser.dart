import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'amount_parser.dart';
import 'language_detector.dart';
import 'categorizer.dart';

/// Main expense parser that orchestrates language detection,
/// amount extraction, and auto-categorization
class ExpenseParser {
  static const _uuid = Uuid();

  /// Parse raw input string into a structured Expense object
  /// Returns ParseResult with the expense and metadata
  static ParseResult parse(String rawInput, String userId) {
    // Validate input
    if (rawInput.trim().isEmpty) {
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

    // Step 2: Extract amount and description
    final amountResult = AmountParser.extractAmount(trimmedInput);

    if (amountResult == null) {
      return ParseResult(
        success: false,
        errorMessage: 'Could not find a valid amount in the input',
      );
    }

    // Validate amount
    if (amountResult.amount <= 0) {
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
    }

    // Step 4: Auto-categorize based on description
    final categoryResult = Categorizer.categorize(description, language);

    // Calculate overall confidence
    // Weight: 50% categorization, 30% language detection, 20% amount parsing
    final overallConfidence = (categoryResult.confidence * 0.5) +
        (languageConfidence * 0.3) +
        (0.2); // Amount parsing is assumed successful if we got here

    // Step 5: Create Expense object
    final expense = Expense(
      id: _uuid.v4(),
      amount: amountResult.amount,
      description: description,
      category: categoryResult.category,
      language: language,
      date: DateTime.now(),
      userId: userId,
      rawInput: rawInput,
      confidence: overallConfidence,
    );

    return ParseResult(
      success: true,
      expense: expense,
      language: language,
      languageConfidence: languageConfidence,
      categoryConfidence: categoryResult.confidence,
      overallConfidence: overallConfidence,
      suggestedCategories: Categorizer.getAllMatches(description, language),
    );
  }

  /// Parse with custom category (user override)
  static ParseResult parseWithCategory(
    String rawInput,
    String userId,
    ExpenseCategory category,
  ) {
    final result = parse(rawInput, userId);

    if (!result.success || result.expense == null) {
      return result;
    }

    // Override category with user's choice
    final updatedExpense = result.expense!.copyWith(
      category: category,
      confidence: 1.0, // User confirmed, so confidence is 100%
    );

    return ParseResult(
      success: true,
      expense: updatedExpense,
      language: result.language,
      languageConfidence: result.languageConfidence,
      categoryConfidence: 1.0, // User confirmed
      overallConfidence: 1.0,
      suggestedCategories: result.suggestedCategories,
    );
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

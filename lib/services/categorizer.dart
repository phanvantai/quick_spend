import '../models/category.dart';
import '../models/expense.dart';

/// Service for auto-categorizing expenses based on description keywords
class Categorizer {
  /// Categorize expense based on description
  /// Returns CategoryResult with the matched category ID and confidence score
  /// Note: Categories now contain keywords in a single language (set during onboarding)
  static CategoryResult categorize(
    String description,
    List<QuickCategory> categories, {
    TransactionType type = TransactionType.expense,
  }) {
    // Determine fallback category based on type
    final fallbackCategory = type == TransactionType.income ? 'other_income' : 'other';

    if (description.isEmpty || categories.isEmpty) {
      return CategoryResult(
        categoryId: fallbackCategory,
        confidence: 0.0,
      );
    }

    final normalizedDesc = description.toLowerCase().trim();

    // Track best match
    String bestCategoryId = fallbackCategory;
    double bestScore = 0.0;
    int bestMatchCount = 0;

    // Filter categories by type
    final relevantCategories = categories.where((cat) => cat.type == type).toList();

    // Check each category
    for (final category in relevantCategories) {
      // Skip 'other' and 'other_income' categories in matching
      if (category.id == 'other' || category.id == 'other_income') continue;

      final keywords = category.keywords;
      int matchCount = 0;
      double score = 0.0;

      // Check for keyword matches
      for (final keyword in keywords) {
        if (normalizedDesc.contains(keyword.toLowerCase())) {
          matchCount++;

          // Exact word match gets higher score
          final wordPattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b',
              caseSensitive: false);
          if (wordPattern.hasMatch(normalizedDesc)) {
            score += 2.0; // Exact word match
          } else {
            score += 1.0; // Substring match
          }
        }
      }

      // Update best match if this category has better score
      if (matchCount > 0 && score > bestScore) {
        bestScore = score;
        bestCategoryId = category.id;
        bestMatchCount = matchCount;
      }
    }

    // Calculate confidence based on match count and score
    double confidence;
    if (bestMatchCount == 0) {
      // No matches found
      confidence = 0.0;
      bestCategoryId = fallbackCategory;
    } else if (bestMatchCount == 1) {
      // Single match - moderate confidence
      confidence = 0.6;
    } else if (bestMatchCount == 2) {
      // Two matches - high confidence
      confidence = 0.8;
    } else {
      // Multiple matches - very high confidence
      confidence = 0.95;
    }

    return CategoryResult(
      categoryId: bestCategoryId,
      confidence: confidence,
      matchCount: bestMatchCount,
    );
  }

  /// Get all possible categories for a description
  /// Returns a list of CategoryResult sorted by confidence (highest first)
  /// Note: Categories now contain keywords in a single language (set during onboarding)
  static List<CategoryResult> getAllMatches(
    String description,
    List<QuickCategory> categories, {
    TransactionType type = TransactionType.expense,
  }) {
    // Determine fallback category based on type
    final fallbackCategory = type == TransactionType.income ? 'other_income' : 'other';

    if (description.isEmpty || categories.isEmpty) {
      return [
        CategoryResult(
          categoryId: fallbackCategory,
          confidence: 0.0,
        )
      ];
    }

    final normalizedDesc = description.toLowerCase().trim();
    final results = <CategoryResult>[];

    // Filter categories by type
    final relevantCategories = categories.where((cat) => cat.type == type).toList();

    // Check each category
    for (final category in relevantCategories) {
      if (category.id == 'other' || category.id == 'other_income') continue;

      final keywords = category.keywords;
      int matchCount = 0;

      for (final keyword in keywords) {
        if (normalizedDesc.contains(keyword.toLowerCase())) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        double confidence;
        if (matchCount == 1) {
          confidence = 0.6;
        } else if (matchCount == 2) {
          confidence = 0.8;
        } else {
          confidence = 0.95;
        }

        results.add(CategoryResult(
          categoryId: category.id,
          confidence: confidence,
          matchCount: matchCount,
        ));
      }
    }

    // Sort by confidence (highest first)
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Add fallback category if no matches
    if (results.isEmpty) {
      results.add(CategoryResult(
        categoryId: fallbackCategory,
        confidence: 0.0,
      ));
    }

    return results;
  }

  /// Detect if description suggests income based on keywords
  /// Returns TransactionType.income if income keywords detected, otherwise TransactionType.expense
  static TransactionType detectTransactionType(String description, String language) {
    final normalizedDesc = description.toLowerCase().trim();

    // Income keywords for English and Vietnamese
    final incomeKeywordsEn = {
      'received',
      'earned',
      'got paid',
      'salary',
      'wage',
      'income',
      'paycheck',
      'refund',
      'gift',
      'bonus',
      'reward',
      'prize',
      'allowance',
      'dividend',
      'interest',
      'profit',
      'freelance income',
      'side income',
    };

    final incomeKeywordsVi = {
      'nhận',
      'được',
      'lương',
      'thu nhập',
      'tiền lương',
      'hoàn tiền',
      'hoàn lại',
      'lì xì',
      'quà',
      'thưởng',
      'giải thưởng',
      'tiền mừng',
      'cổ tức',
      'lãi',
      'lợi nhuận',
    };

    final keywords = language == 'vi' ? incomeKeywordsVi : incomeKeywordsEn;

    for (final keyword in keywords) {
      if (normalizedDesc.contains(keyword.toLowerCase())) {
        return TransactionType.income;
      }
    }

    // Default to expense
    return TransactionType.expense;
  }
}

/// Result of categorization
class CategoryResult {
  final String categoryId;
  final double confidence; // 0-1 scale
  final int matchCount;

  CategoryResult({
    required this.categoryId,
    required this.confidence,
    this.matchCount = 0,
  });

  @override
  String toString() {
    return 'CategoryResult(categoryId: $categoryId, confidence: $confidence, matchCount: $matchCount)';
  }
}

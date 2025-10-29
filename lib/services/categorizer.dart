import '../models/category.dart';

/// Service for auto-categorizing expenses based on description keywords
class Categorizer {
  /// Categorize expense based on description and language
  /// Returns CategoryResult with the matched category and confidence score
  static CategoryResult categorize(String description, String language) {
    if (description.isEmpty) {
      return CategoryResult(
        category: ExpenseCategory.other,
        confidence: 0.0,
      );
    }

    final normalizedDesc = description.toLowerCase().trim();
    final categories = Category.getAllCategories();

    // Track best match
    ExpenseCategory bestCategory = ExpenseCategory.other;
    double bestScore = 0.0;
    int bestMatchCount = 0;

    // Check each category
    for (final category in categories) {
      // Skip 'other' category in matching
      if (category.type == ExpenseCategory.other) continue;

      final keywords = category.getKeywords(language);
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
        bestCategory = category.type;
        bestMatchCount = matchCount;
      }
    }

    // Calculate confidence based on match count and score
    double confidence;
    if (bestMatchCount == 0) {
      // No matches found
      confidence = 0.0;
      bestCategory = ExpenseCategory.other;
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
      category: bestCategory,
      confidence: confidence,
      matchCount: bestMatchCount,
    );
  }

  /// Get all possible categories for a description
  /// Returns a list of CategoryResult sorted by confidence (highest first)
  static List<CategoryResult> getAllMatches(String description, String language) {
    if (description.isEmpty) {
      return [
        CategoryResult(
          category: ExpenseCategory.other,
          confidence: 0.0,
        )
      ];
    }

    final normalizedDesc = description.toLowerCase().trim();
    final categories = Category.getAllCategories();
    final results = <CategoryResult>[];

    // Check each category
    for (final category in categories) {
      if (category.type == ExpenseCategory.other) continue;

      final keywords = category.getKeywords(language);
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
          category: category.type,
          confidence: confidence,
          matchCount: matchCount,
        ));
      }
    }

    // Sort by confidence (highest first)
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Add 'other' as fallback if no matches
    if (results.isEmpty) {
      results.add(CategoryResult(
        category: ExpenseCategory.other,
        confidence: 0.0,
      ));
    }

    return results;
  }
}

/// Result of categorization
class CategoryResult {
  final ExpenseCategory category;
  final double confidence; // 0-1 scale
  final int matchCount;

  CategoryResult({
    required this.category,
    required this.confidence,
    this.matchCount = 0,
  });

  @override
  String toString() {
    return 'CategoryResult(category: $category, confidence: $confidence, matchCount: $matchCount)';
  }
}

import '../models/category.dart';

/// Service for auto-categorizing expenses based on description keywords
class Categorizer {
  /// Categorize expense based on description and language
  /// Returns CategoryResult with the matched category ID and confidence score
  static CategoryResult categorize(
    String description,
    String language,
    List<QuickCategory> categories,
  ) {
    if (description.isEmpty || categories.isEmpty) {
      return CategoryResult(
        categoryId: 'other',
        confidence: 0.0,
      );
    }

    final normalizedDesc = description.toLowerCase().trim();

    // Track best match
    String bestCategoryId = 'other';
    double bestScore = 0.0;
    int bestMatchCount = 0;

    // Check each category
    for (final category in categories) {
      // Skip 'other' category in matching
      if (category.id == 'other') continue;

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
        bestCategoryId = category.id;
        bestMatchCount = matchCount;
      }
    }

    // Calculate confidence based on match count and score
    double confidence;
    if (bestMatchCount == 0) {
      // No matches found
      confidence = 0.0;
      bestCategoryId = 'other';
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
  static List<CategoryResult> getAllMatches(
    String description,
    String language,
    List<QuickCategory> categories,
  ) {
    if (description.isEmpty || categories.isEmpty) {
      return [
        CategoryResult(
          categoryId: 'other',
          confidence: 0.0,
        )
      ];
    }

    final normalizedDesc = description.toLowerCase().trim();
    final results = <CategoryResult>[];

    // Check each category
    for (final category in categories) {
      if (category.id == 'other') continue;

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
          categoryId: category.id,
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
        categoryId: 'other',
        confidence: 0.0,
      ));
    }

    return results;
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

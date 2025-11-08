import 'package:flutter/material.dart';
import 'category.dart';

/// Statistics for a single expense category
class CategoryStats {
  final String categoryId;
  final String categoryName; // Store name for display
  final double totalAmount;
  final int count;
  final double percentage;
  final Color color;
  final IconData icon;

  CategoryStats({
    required this.categoryId,
    required this.categoryName,
    required this.totalAmount,
    required this.count,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  /// Create CategoryStats from category data
  factory CategoryStats.fromCategory({
    required QuickCategory category,
    required double totalAmount,
    required int count,
    required double grandTotal,
    required String language,
  }) {
    return CategoryStats(
      categoryId: category.id,
      categoryName: category.getLabel(language),
      totalAmount: totalAmount,
      count: count,
      percentage: grandTotal > 0 ? (totalAmount / grandTotal * 100) : 0,
      color: category.color,
      icon: category.icon,
    );
  }

  /// Legacy: Get category enum (for backward compatibility)
  /// @deprecated Use categoryId directly
  ExpenseCategory get category {
    return ExpenseCategory.values.firstWhere(
      (e) => e.toString().split('.').last == categoryId,
      orElse: () => ExpenseCategory.other,
    );
  }

  /// Get category label
  String getLabel(String language) {
    return categoryName; // Already stored with language
  }

  @override
  String toString() {
    return 'CategoryStats(categoryId: $categoryId, amount: $totalAmount, count: $count, percentage: ${percentage.toStringAsFixed(1)}%)';
  }
}

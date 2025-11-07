import 'package:flutter/material.dart';
import 'category.dart';

/// Statistics for a single expense category
class CategoryStats {
  final ExpenseCategory category;
  final double totalAmount;
  final int count;
  final double percentage;
  final Color color;
  final IconData icon;

  CategoryStats({
    required this.category,
    required this.totalAmount,
    required this.count,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  /// Create CategoryStats from list of expenses
  factory CategoryStats.fromCategory({
    required ExpenseCategory category,
    required double totalAmount,
    required int count,
    required double grandTotal,
  }) {
    final categoryData = Category.getByType(category);
    return CategoryStats(
      category: category,
      totalAmount: totalAmount,
      count: count,
      percentage: grandTotal > 0 ? (totalAmount / grandTotal * 100) : 0,
      color: categoryData.color,
      icon: categoryData.icon,
    );
  }

  /// Get category label in specified language
  String getLabel(String language) {
    return Category.getByType(category).getLabel(language);
  }

  @override
  String toString() {
    return 'CategoryStats(category: $category, amount: $totalAmount, count: $count, percentage: ${percentage.toStringAsFixed(1)}%)';
  }
}

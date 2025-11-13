import 'package:flutter/material.dart';
import 'category.dart';
import 'expense.dart';

/// Statistics for a single expense category
class CategoryStats {
  final String categoryId;
  final String categoryName; // Store name for display
  final double totalAmount;
  final int count;
  final double percentage;
  final Color color;
  final IconData icon;
  final TransactionType type; // Income or expense

  CategoryStats({
    required this.categoryId,
    required this.categoryName,
    required this.totalAmount,
    required this.count,
    required this.percentage,
    required this.color,
    required this.icon,
    required this.type,
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
      categoryName: category.name,
      totalAmount: totalAmount,
      count: count,
      percentage: grandTotal > 0 ? (totalAmount / grandTotal * 100) : 0,
      color: category.color,
      icon: category.icon,
      type: category.type,
    );
  }

  /// Get category label
  String getLabel(String language) {
    return categoryName; // Already stored with language
  }

  /// Check if this is an income category
  bool get isIncomeCategory => type == TransactionType.income;

  /// Check if this is an expense category
  bool get isExpenseCategory => type == TransactionType.expense;

  @override
  String toString() {
    return 'CategoryStats(categoryId: $categoryId, amount: $totalAmount, count: $count, percentage: ${percentage.toStringAsFixed(1)}%)';
  }
}

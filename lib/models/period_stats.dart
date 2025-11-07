import '../models/expense.dart';
import '../models/category.dart';
import 'category_stats.dart';

/// Statistics for a specific time period
class PeriodStats {
  final double totalAmount;
  final int transactionCount;
  final double averagePerDay;
  final double averagePerTransaction;
  final Expense? highestExpense;
  final Expense? lowestExpense;
  final List<CategoryStats> categoryBreakdown;
  final Map<DateTime, double> dailySpending;
  final DateTime startDate;
  final DateTime endDate;

  PeriodStats({
    required this.totalAmount,
    required this.transactionCount,
    required this.averagePerDay,
    required this.averagePerTransaction,
    this.highestExpense,
    this.lowestExpense,
    required this.categoryBreakdown,
    required this.dailySpending,
    required this.startDate,
    required this.endDate,
  });

  /// Create empty statistics
  factory PeriodStats.empty({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return PeriodStats(
      totalAmount: 0,
      transactionCount: 0,
      averagePerDay: 0,
      averagePerTransaction: 0,
      categoryBreakdown: [],
      dailySpending: {},
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculate statistics from list of expenses
  factory PeriodStats.fromExpenses({
    required List<Expense> expenses,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (expenses.isEmpty) {
      return PeriodStats.empty(startDate: startDate, endDate: endDate);
    }

    // Calculate total and averages
    final totalAmount = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final transactionCount = expenses.length;

    // Calculate days in period
    final daysDifference = endDate.difference(startDate).inDays + 1;
    final averagePerDay = totalAmount / daysDifference;

    final averagePerTransaction = totalAmount / transactionCount;

    // Find highest and lowest expenses
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    final highestExpense = expenses.first;
    final lowestExpense = expenses.last;

    // Calculate category breakdown
    final categoryTotals = <ExpenseCategory, double>{};
    final categoryCounts = <ExpenseCategory, int>{};

    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
      categoryCounts[expense.category] =
          (categoryCounts[expense.category] ?? 0) + 1;
    }

    final categoryBreakdown = categoryTotals.entries
        .map((entry) => CategoryStats.fromCategory(
              category: entry.key,
              totalAmount: entry.value,
              count: categoryCounts[entry.key] ?? 0,
              grandTotal: totalAmount,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Calculate daily spending
    final dailySpending = <DateTime, double>{};
    for (final expense in expenses) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailySpending[date] = (dailySpending[date] ?? 0) + expense.amount;
    }

    return PeriodStats(
      totalAmount: totalAmount,
      transactionCount: transactionCount,
      averagePerDay: averagePerDay,
      averagePerTransaction: averagePerTransaction,
      highestExpense: highestExpense,
      lowestExpense: lowestExpense,
      categoryBreakdown: categoryBreakdown,
      dailySpending: dailySpending,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get top N expenses
  List<Expense> getTopExpenses(List<Expense> allExpenses, {int limit = 5}) {
    final sortedExpenses = List<Expense>.from(allExpenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sortedExpenses.take(limit).toList();
  }

  @override
  String toString() {
    return 'PeriodStats(total: $totalAmount, count: $transactionCount, avg/day: ${averagePerDay.toStringAsFixed(2)})';
  }
}

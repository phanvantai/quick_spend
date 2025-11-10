import '../models/expense.dart';
import '../models/category.dart';
import 'category_stats.dart';

/// Statistics for a specific time period
class PeriodStats {
  final double totalAmount; // Total of all transactions (for backward compatibility)
  final double totalIncome; // Total income only
  final double totalExpenses; // Total expenses only
  final double netBalance; // Income - Expenses
  final double savingsRate; // (Income - Expenses) / Income * 100
  final int transactionCount;
  final int incomeCount; // Number of income transactions
  final int expenseCount; // Number of expense transactions
  final double averagePerDay;
  final double averagePerTransaction;
  final Expense? highestExpense;
  final Expense? lowestExpense;
  final Expense? highestIncome;
  final Expense? lowestIncome;
  final List<CategoryStats> categoryBreakdown;
  final Map<DateTime, double> dailySpending; // Daily spending (expenses only)
  final Map<DateTime, double> dailyIncome; // Daily income
  final Map<DateTime, double> dailyNet; // Daily net (income - expenses)
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, double> categoryTotals; // Store for later calculation
  final Map<String, int> categoryCounts; // Store for later calculation

  PeriodStats({
    required this.totalAmount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
    required this.savingsRate,
    required this.transactionCount,
    required this.incomeCount,
    required this.expenseCount,
    required this.averagePerDay,
    required this.averagePerTransaction,
    this.highestExpense,
    this.lowestExpense,
    this.highestIncome,
    this.lowestIncome,
    required this.categoryBreakdown,
    required this.dailySpending,
    required this.dailyIncome,
    required this.dailyNet,
    required this.startDate,
    required this.endDate,
    required this.categoryTotals,
    required this.categoryCounts,
  });

  /// Create empty statistics
  factory PeriodStats.empty({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return PeriodStats(
      totalAmount: 0,
      totalIncome: 0,
      totalExpenses: 0,
      netBalance: 0,
      savingsRate: 0,
      transactionCount: 0,
      incomeCount: 0,
      expenseCount: 0,
      averagePerDay: 0,
      averagePerTransaction: 0,
      categoryBreakdown: [],
      dailySpending: {},
      dailyIncome: {},
      dailyNet: {},
      startDate: startDate,
      endDate: endDate,
      categoryTotals: {},
      categoryCounts: {},
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

    // Separate income and expenses
    final incomeTransactions = expenses.where((e) => e.isIncome).toList();
    final expenseTransactions = expenses.where((e) => e.isExpense).toList();

    // Calculate totals
    final totalIncome = incomeTransactions.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final totalExpenses = expenseTransactions.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    final totalAmount = totalIncome + totalExpenses;
    final netBalance = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? ((netBalance / totalIncome) * 100) : 0.0;

    final transactionCount = expenses.length;
    final incomeCount = incomeTransactions.length;
    final expenseCount = expenseTransactions.length;

    // Calculate days in period
    final daysDifference = endDate.difference(startDate).inDays + 1;
    final averagePerDay = totalExpenses / daysDifference; // Average spending per day

    final averagePerTransaction = transactionCount > 0 ? totalAmount / transactionCount : 0.0;

    // Find highest and lowest expenses
    Expense? highestExpense;
    Expense? lowestExpense;
    if (expenseTransactions.isNotEmpty) {
      expenseTransactions.sort((a, b) => b.amount.compareTo(a.amount));
      highestExpense = expenseTransactions.first;
      lowestExpense = expenseTransactions.last;
    }

    // Find highest and lowest income
    Expense? highestIncome;
    Expense? lowestIncome;
    if (incomeTransactions.isNotEmpty) {
      incomeTransactions.sort((a, b) => b.amount.compareTo(a.amount));
      highestIncome = incomeTransactions.first;
      lowestIncome = incomeTransactions.last;
    }

    // Calculate category breakdown
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0) + expense.amount;
      categoryCounts[expense.categoryId] =
          (categoryCounts[expense.categoryId] ?? 0) + 1;
    }

    // Note: categoryBreakdown calculation needs to be done in ReportProvider
    // where we have access to CategoryProvider to resolve categoryId -> Category
    final categoryBreakdown = <CategoryStats>[];

    // Calculate daily spending (expenses only)
    final dailySpending = <DateTime, double>{};
    for (final expense in expenseTransactions) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailySpending[date] = (dailySpending[date] ?? 0) + expense.amount;
    }

    // Calculate daily income
    final dailyIncome = <DateTime, double>{};
    for (final expense in incomeTransactions) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailyIncome[date] = (dailyIncome[date] ?? 0) + expense.amount;
    }

    // Calculate daily net (income - expenses)
    final dailyNet = <DateTime, double>{};
    final allDates = {...dailySpending.keys, ...dailyIncome.keys};
    for (final date in allDates) {
      final income = dailyIncome[date] ?? 0;
      final spending = dailySpending[date] ?? 0;
      dailyNet[date] = income - spending;
    }

    return PeriodStats(
      totalAmount: totalAmount,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netBalance: netBalance,
      savingsRate: savingsRate,
      transactionCount: transactionCount,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
      averagePerDay: averagePerDay,
      averagePerTransaction: averagePerTransaction,
      highestExpense: highestExpense,
      lowestExpense: lowestExpense,
      highestIncome: highestIncome,
      lowestIncome: lowestIncome,
      categoryBreakdown: categoryBreakdown,
      dailySpending: dailySpending,
      dailyIncome: dailyIncome,
      dailyNet: dailyNet,
      startDate: startDate,
      endDate: endDate,
      categoryTotals: categoryTotals,
      categoryCounts: categoryCounts,
    );
  }

  /// Create a copy with calculated category breakdown
  /// Percentages are calculated separately for expenses and income:
  /// - Expense categories: percentage of totalExpenses
  /// - Income categories: percentage of totalIncome
  PeriodStats withCategoryBreakdown(
    List<QuickCategory> allCategories,
    String language,
  ) {
    final breakdown = <CategoryStats>[];

    for (final entry in categoryTotals.entries) {
      final categoryId = entry.key;
      final category = allCategories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => allCategories.firstWhere((cat) => cat.id == 'other'),
      );

      // Use the appropriate grand total based on transaction type
      // Expense categories should be % of totalExpenses
      // Income categories should be % of totalIncome
      final grandTotal = category.type == TransactionType.expense
          ? totalExpenses
          : totalIncome;

      breakdown.add(CategoryStats.fromCategory(
        category: category,
        totalAmount: entry.value,
        count: categoryCounts[categoryId] ?? 0,
        grandTotal: grandTotal,
        language: language,
      ));
    }

    breakdown.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return PeriodStats(
      totalAmount: totalAmount,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netBalance: netBalance,
      savingsRate: savingsRate,
      transactionCount: transactionCount,
      incomeCount: incomeCount,
      expenseCount: expenseCount,
      averagePerDay: averagePerDay,
      averagePerTransaction: averagePerTransaction,
      highestExpense: highestExpense,
      lowestExpense: lowestExpense,
      highestIncome: highestIncome,
      lowestIncome: lowestIncome,
      categoryBreakdown: breakdown,
      dailySpending: dailySpending,
      dailyIncome: dailyIncome,
      dailyNet: dailyNet,
      startDate: startDate,
      endDate: endDate,
      categoryTotals: categoryTotals,
      categoryCounts: categoryCounts,
    );
  }

  /// Get income category breakdown only
  List<CategoryStats> get incomeCategoryBreakdown {
    return categoryBreakdown
        .where((stat) => stat.isIncomeCategory)
        .toList();
  }

  /// Get expense category breakdown only
  List<CategoryStats> get expenseCategoryBreakdown {
    return categoryBreakdown
        .where((stat) => stat.isExpenseCategory)
        .toList();
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

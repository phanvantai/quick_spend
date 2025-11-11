import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/recurring_expense_service.dart';
import '../utils/constants.dart';

/// Provider for managing expense state
class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _expenseService;
  final RecurringExpenseService? _recurringExpenseService;
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _currentUserId = AppConstants.defaultUserId;

  ExpenseProvider(
    this._expenseService, {
    RecurringExpenseService? recurringExpenseService,
  }) : _recurringExpenseService = recurringExpenseService {
    _loadExpenses();
  }

  /// Current list of expenses
  List<Expense> get expenses => _expenses;

  /// Whether the provider is loading
  bool get isLoading => _isLoading;

  /// Current user ID
  String get currentUserId => _currentUserId;

  /// Total number of transactions (both expenses and income)
  int get transactionCount => _expenses.length;

  /// Total number of expenses only
  int get expenseCount => _expenses.where((e) => e.isExpense).length;

  /// Total number of income only
  int get incomeCount => _expenses.where((e) => e.isIncome).length;

  /// List of expenses only (filtered)
  List<Expense> get expensesOnly =>
      _expenses.where((e) => e.isExpense).toList();

  /// List of income only (filtered)
  List<Expense> get incomeOnly => _expenses.where((e) => e.isIncome).toList();

  /// Total amount spent (expenses only)
  double get totalExpenses => _expenses
      .where((e) => e.isExpense)
      .fold(0.0, (sum, expense) => sum + expense.amount);

  /// Total income received
  double get totalIncome => _expenses
      .where((e) => e.isIncome)
      .fold(0.0, (sum, expense) => sum + expense.amount);

  /// Net balance (income - expenses)
  double get netBalance => totalIncome - totalExpenses;

  /// Savings rate as percentage (0-100)
  /// Returns 0 if no income
  double get savingsRate {
    if (totalIncome == 0) return 0.0;
    return ((totalIncome - totalExpenses) / totalIncome) * 100;
  }

  /// Total amount (for backward compatibility - expenses only)
  @Deprecated('Use totalExpenses instead')
  double get totalAmount => totalExpenses;

  /// Set the current user ID (for future multi-user support)
  void setUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadExpenses();
    }
  }

  /// Load expenses from database
  Future<void> _loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = await _expenseService.getAllExpenses(_currentUserId);
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      _expenses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reload expenses from database
  Future<void> refresh() async {
    await _loadExpenses();
  }

  /// Generate pending recurring expenses
  /// This should be called when the app starts
  Future<int> generateRecurringExpenses() async {
    if (_recurringExpenseService == null) {
      debugPrint('⚠️ [ExpenseProvider] RecurringExpenseService not available');
      return 0;
    }

    try {
      debugPrint('🔄 [ExpenseProvider] Generating recurring expenses...');
      final count = await _recurringExpenseService.generatePendingExpenses(
        _currentUserId,
      );

      if (count > 0) {
        debugPrint(
          '✅ [ExpenseProvider] Generated $count recurring expense(s), refreshing list...',
        );
        // Reload expenses without showing loading state
        _expenses = await _expenseService.getAllExpenses(_currentUserId);
        notifyListeners();
      } else {
        debugPrint('[ExpenseProvider] No recurring expenses to generate');
      }

      return count;
    } catch (e) {
      debugPrint('❌ [ExpenseProvider] Error generating recurring expenses: $e');
      return 0;
    }
  }

  /// Add a new expense
  Future<void> addExpense(Expense expense) async {
    try {
      await _expenseService.saveExpense(expense);
      _expenses.insert(0, expense); // Add to beginning (newest first)
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  /// Add multiple expenses at once (useful for batch imports)
  Future<void> addExpenses(List<Expense> expenses) async {
    try {
      debugPrint(
        '💾 [ExpenseProvider] Saving ${expenses.length} expense(s)...',
      );
      for (final expense in expenses) {
        await _expenseService.saveExpense(expense);
      }
      // Reload expenses from database without showing loading state
      _expenses = await _expenseService.getAllExpenses(_currentUserId);
      debugPrint(
        '✅ [ExpenseProvider] Saved! Total expenses now: ${_expenses.length}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ExpenseProvider] Error adding expenses: $e');
      rethrow;
    }
  }

  /// Update an existing expense
  Future<void> updateExpense(Expense expense) async {
    try {
      await _expenseService.updateExpense(expense);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _expenseService.deleteExpense(expenseId);
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }

  /// Delete all expenses
  Future<void> deleteAllExpenses() async {
    try {
      await _expenseService.deleteAllExpenses(_currentUserId);
      _expenses.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting all expenses: $e');
      rethrow;
    }
  }

  /// Get expenses for a specific date range
  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _expenseService.getExpensesByDateRange(
        _currentUserId,
        startDate,
        endDate,
      );
    } catch (e) {
      debugPrint('Error getting expenses by date range: $e');
      return [];
    }
  }

  /// Get expenses for today
  Future<List<Expense>> getTodayExpenses() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getExpensesByDateRange(startOfDay, endOfDay);
  }

  /// Get expenses for this month
  Future<List<Expense>> getThisMonthExpenses() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getExpensesByDateRange(startOfMonth, endOfMonth);
  }

  /// Get expenses only for a specific date range
  Future<List<Expense>> getExpensesOnlyByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _expenseService.getTransactionsByDateRangeAndType(
        _currentUserId,
        startDate,
        endDate,
        'expense',
      );
    } catch (e) {
      debugPrint('Error getting expenses by date range: $e');
      return [];
    }
  }

  /// Get income only for a specific date range
  Future<List<Expense>> getIncomeOnlyByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _expenseService.getTransactionsByDateRangeAndType(
        _currentUserId,
        startDate,
        endDate,
        'income',
      );
    } catch (e) {
      debugPrint('Error getting income by date range: $e');
      return [];
    }
  }

  /// Get transactions by type from current loaded data
  List<Expense> filterByType(TransactionType type) {
    return _expenses.where((e) => e.type == type).toList();
  }

  /// Reset all data (for testing)
  Future<void> reset() async {
    await _expenseService.clearAll();
    await _loadExpenses();
  }
}

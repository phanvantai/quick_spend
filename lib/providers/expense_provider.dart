import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../utils/constants.dart';

/// Provider for managing expense state
class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _expenseService;
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _currentUserId = AppConstants.defaultUserId;

  ExpenseProvider(this._expenseService) {
    _initializeAndMigrate();
  }

  /// Initialize provider and migrate any legacy data
  Future<void> _initializeAndMigrate() async {
    await _migrateWrongUserIds();
    await _loadExpenses();
  }

  /// Migrate expenses with incorrect userIds to the correct one
  Future<void> _migrateWrongUserIds() async {
    try {
      debugPrint('🔄 [ExpenseProvider] Checking for userId migration...');
      await _expenseService.migrateUserIds(AppConstants.defaultUserId);
      debugPrint('✅ [ExpenseProvider] UserId migration completed');
    } catch (e) {
      debugPrint('❌ [ExpenseProvider] Error during userId migration: $e');
      // Don't throw - continue loading even if migration fails
    }
  }

  /// Current list of expenses
  List<Expense> get expenses => _expenses;

  /// Whether the provider is loading
  bool get isLoading => _isLoading;

  /// Current user ID
  String get currentUserId => _currentUserId;

  /// Total number of expenses
  int get expenseCount => _expenses.length;

  /// Total amount spent
  double get totalAmount => _expenses.fold(0.0, (sum, expense) => sum + expense.amount);

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
      debugPrint('💾 [ExpenseProvider] Saving ${expenses.length} expense(s)...');
      for (final expense in expenses) {
        await _expenseService.saveExpense(expense);
      }
      // Reload expenses from database without showing loading state
      _expenses = await _expenseService.getAllExpenses(_currentUserId);
      debugPrint('✅ [ExpenseProvider] Saved! Total expenses now: ${_expenses.length}');
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

  /// Reset all data (for testing)
  Future<void> reset() async {
    await _expenseService.clearAll();
    await _loadExpenses();
  }
}

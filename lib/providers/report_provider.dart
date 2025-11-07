import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/period_stats.dart';
import '../utils/date_range_helper.dart';
import 'expense_provider.dart';

/// Provider for managing report data and filtering
class ReportProvider extends ChangeNotifier {
  final ExpenseProvider _expenseProvider;

  TimePeriod _selectedPeriod = TimePeriod.thisMonth;
  DateRange? _customDateRange;
  PeriodStats? _currentStats;
  PeriodStats? _previousStats;
  bool _isCalculating = false;

  ReportProvider(this._expenseProvider) {
    _expenseProvider.addListener(_onExpensesChanged);
    _calculateStats();
  }

  @override
  void dispose() {
    _expenseProvider.removeListener(_onExpensesChanged);
    super.dispose();
  }

  /// Called when expenses change in ExpenseProvider
  void _onExpensesChanged() {
    _calculateStats();
  }

  /// Currently selected time period
  TimePeriod get selectedPeriod => _selectedPeriod;

  /// Custom date range (if period is custom)
  DateRange? get customDateRange => _customDateRange;

  /// Current period statistics
  PeriodStats? get currentStats => _currentStats;

  /// Previous period statistics (for comparison)
  PeriodStats? get previousStats => _previousStats;

  /// Whether statistics are being calculated
  bool get isCalculating => _isCalculating;

  /// Whether data is loading
  bool get isLoading => _expenseProvider.isLoading || _isCalculating;

  /// Get current date range based on selected period
  DateRange get currentDateRange {
    if (_selectedPeriod == TimePeriod.custom && _customDateRange != null) {
      return _customDateRange!;
    }
    return _selectedPeriod.getDateRange();
  }

  /// Get trend percentage compared to previous period
  double? get trendPercentage {
    if (_currentStats == null || _previousStats == null) return null;
    if (_previousStats!.totalAmount == 0) return null;

    final change =
        _currentStats!.totalAmount - _previousStats!.totalAmount;
    return (change / _previousStats!.totalAmount) * 100;
  }

  /// Whether trend is positive (spending increased)
  bool get isTrendPositive {
    final trend = trendPercentage;
    return trend != null && trend > 0;
  }

  /// Select a time period and recalculate stats
  void selectPeriod(TimePeriod period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      _customDateRange = null;
      _calculateStats();
    }
  }

  /// Set custom date range and recalculate stats
  void setCustomDateRange(DateTime start, DateTime end) {
    _selectedPeriod = TimePeriod.custom;
    _customDateRange = DateRange(start: start, end: end);
    _calculateStats();
  }

  /// Calculate statistics for current and previous periods
  Future<void> _calculateStats() async {
    _isCalculating = true;
    notifyListeners();

    try {
      final dateRange = currentDateRange;

      // Get expenses for current period
      final currentExpenses = await _expenseProvider.getExpensesByDateRange(
        dateRange.start,
        dateRange.end,
      );

      // Calculate current period stats
      _currentStats = PeriodStats.fromExpenses(
        expenses: currentExpenses,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );

      // Get previous period for comparison
      final previousRange = DateRangeHelper.getPreviousPeriod(
        dateRange.start,
        dateRange.end,
      );

      final previousExpenses = await _expenseProvider.getExpensesByDateRange(
        previousRange.start,
        previousRange.end,
      );

      // Calculate previous period stats
      _previousStats = PeriodStats.fromExpenses(
        expenses: previousExpenses,
        startDate: previousRange.start,
        endDate: previousRange.end,
      );
    } catch (e) {
      debugPrint('❌ [ReportProvider] Error calculating stats: $e');
      _currentStats = null;
      _previousStats = null;
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  /// Refresh statistics
  Future<void> refresh() async {
    await _calculateStats();
  }

  /// Get filtered expenses for current period
  Future<List<Expense>> getCurrentExpenses() async {
    final dateRange = currentDateRange;
    return _expenseProvider.getExpensesByDateRange(
      dateRange.start,
      dateRange.end,
    );
  }

  /// Get top expenses for current period
  Future<List<Expense>> getTopExpenses({int limit = 5}) async {
    final expenses = await getCurrentExpenses();
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sortedExpenses.take(limit).toList();
  }
}

import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/period_stats.dart';
import '../utils/constants.dart';
import '../utils/date_range_helper.dart';
import '../services/subscription_service.dart';
import 'expense_provider.dart';
import 'category_provider.dart';
import 'app_config_provider.dart';

/// Provider for managing report data and filtering
class ReportProvider extends ChangeNotifier {
  final ExpenseProvider _expenseProvider;
  final CategoryProvider _categoryProvider;
  final AppConfigProvider _appConfigProvider;
  bool _isPremium = false;

  TimePeriod _selectedPeriod = TimePeriod.thisMonth;
  DateRange? _customDateRange;
  PeriodStats? _currentStats;
  PeriodStats? _previousStats;
  List<Expense> _topExpenses = [];
  bool _isCalculating = false;

  ReportProvider(
    this._expenseProvider,
    this._categoryProvider,
    this._appConfigProvider,
  ) {
    _expenseProvider.addListener(_onExpensesChanged);
    _categoryProvider.addListener(_onCategoriesChanged);
    _initialize();
  }

  /// Initialize subscription status and calculate stats
  Future<void> _initialize() async {
    _isPremium = await SubscriptionService.isPremium();

    // Set appropriate default period based on subscription tier
    // Free users: default to thisWeek (available period)
    // Premium users: keep thisMonth (all periods available)
    if (!_isPremium && _selectedPeriod == TimePeriod.thisMonth) {
      _selectedPeriod = TimePeriod.thisWeek;
    }

    await _calculateStats();
  }

  @override
  void dispose() {
    _expenseProvider.removeListener(_onExpensesChanged);
    _categoryProvider.removeListener(_onCategoriesChanged);
    super.dispose();
  }

  /// Called when expenses change in ExpenseProvider
  void _onExpensesChanged() {
    _calculateStats();
  }

  /// Called when categories change in CategoryProvider
  void _onCategoriesChanged() {
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

  /// Top expenses for current period
  List<Expense> get topExpenses => _topExpenses;

  /// Whether statistics are being calculated
  bool get isCalculating => _isCalculating;

  /// Whether data is loading
  bool get isLoading => _expenseProvider.isLoading || _isCalculating;

  /// Whether user has premium subscription
  bool get isPremium => _isPremium;

  /// Get available periods based on subscription tier
  List<TimePeriod> get availablePeriods {
    if (_isPremium) {
      // Premium: all periods available
      return TimePeriod.values;
    } else {
      // Free: only today and thisWeek (≤7 days)
      return [TimePeriod.today, TimePeriod.thisWeek];
    }
  }

  /// Check if a period is allowed for current subscription tier
  bool isPeriodAllowed(TimePeriod period) {
    return availablePeriods.contains(period);
  }

  /// Check if a custom date range is allowed (free tier: max 7 days)
  bool isDateRangeAllowed(DateTime start, DateTime end) {
    if (_isPremium) return true;

    final days = end.difference(start).inDays + 1;
    return days <= AppConstants.freeTierReportDaysLimit;
  }

  /// Get current date range based on selected period
  /// Free tier: automatically limited to last 7 days
  DateRange get currentDateRange {
    if (_selectedPeriod == TimePeriod.custom && _customDateRange != null) {
      return _customDateRange!;
    }

    final range = _selectedPeriod.getDateRange();

    // For free tier, limit to last 7 days
    if (!_isPremium) {
      final now = DateTime.now();
      final maxStart = now.subtract(
        Duration(days: AppConstants.freeTierReportDaysLimit - 1),
      );
      if (range.start.isBefore(maxStart)) {
        // Adjust to last 7 days
        return DateRange(
          start: DateTime(maxStart.year, maxStart.month, maxStart.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      }
    }

    return range;
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
  /// Returns false if period is not allowed for current subscription tier
  bool selectPeriod(TimePeriod period) {
    // Check if period is allowed
    if (!isPeriodAllowed(period)) {
      debugPrint('⚠️ [ReportProvider] Period $period not allowed for free tier');
      return false;
    }

    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      _customDateRange = null;
      _calculateStats();
    }
    return true;
  }

  /// Set custom date range and recalculate stats
  /// Returns false if date range exceeds free tier limit (7 days)
  bool setCustomDateRange(DateTime start, DateTime end) {
    // Check if date range is allowed
    if (!isDateRangeAllowed(start, end)) {
      debugPrint(
        '⚠️ [ReportProvider] Date range exceeds free tier limit (${AppConstants.freeTierReportDaysLimit} days)',
      );
      return false;
    }

    _selectedPeriod = TimePeriod.custom;
    _customDateRange = DateRange(start: start, end: end);
    _calculateStats();
    return true;
  }

  /// Refresh subscription status (call when subscription changes)
  Future<void> refreshSubscription() async {
    final wasPremium = _isPremium;
    _isPremium = await SubscriptionService.isPremium();

    // If downgraded to free and current period is not allowed, switch to thisWeek
    if (wasPremium && !_isPremium && !isPeriodAllowed(_selectedPeriod)) {
      debugPrint(
        '⚠️ [ReportProvider] User downgraded - switching from $_selectedPeriod to thisWeek',
      );
      _selectedPeriod = TimePeriod.thisWeek;
      _customDateRange = null;
      await _calculateStats();
    } else {
      notifyListeners();
    }
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
      final currentStatsRaw = PeriodStats.fromExpenses(
        expenses: currentExpenses,
        startDate: dateRange.start,
        endDate: dateRange.end,
      );

      // Add category breakdown using CategoryProvider
      final language = _appConfigProvider.language;
      final categories = _categoryProvider.categories;
      _currentStats = currentStatsRaw.withCategoryBreakdown(categories, language);

      // Calculate top expenses (sorted by amount, descending)
      // Only include expense type transactions, not income
      _topExpenses = currentExpenses.where((e) => e.isExpense).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

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
      final previousStatsRaw = PeriodStats.fromExpenses(
        expenses: previousExpenses,
        startDate: previousRange.start,
        endDate: previousRange.end,
      );
      _previousStats = previousStatsRaw.withCategoryBreakdown(categories, language);
    } catch (e) {
      debugPrint('❌ [ReportProvider] Error calculating stats: $e');
      _currentStats = null;
      _previousStats = null;
      _topExpenses = [];
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
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/app_config_provider.dart';
import '../services/data_collection_service.dart';
import '../theme/app_theme.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../widgets/calendar/month_navigator.dart';
import '../widgets/calendar/calendar_grid.dart';
import '../widgets/calendar/monthly_summary_card.dart';
import '../widgets/calendar/date_section_header.dart';
import '../widgets/common/expense_card.dart';
import '../widgets/common/empty_state.dart';
import 'expense_form_screen.dart';
import 'settings_screen.dart';

/// Report screen with calendar view and grouped transactions
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, GlobalKey> _dateHeaderKeys = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
      _selectedDate = null; // Reset selected date when month changes
    });
  }

  void _onDayTap(DateTime date) {
    setState(() {
      _selectedDate = date;
    });

    // Scroll to date section
    final dateKey = _dateHeaderKeys[DateTime(date.year, date.month, date.day)];
    if (dateKey != null && dateKey.currentContext != null) {
      Scrollable.ensureVisible(
        dateKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1, // Position near top of viewport
      );
    }
  }

  List<Expense> _getExpensesForMonth(List<Expense> allExpenses) {
    return allExpenses.where((expense) {
      return expense.date.year == _selectedMonth.year &&
          expense.date.month == _selectedMonth.month;
    }).toList();
  }

  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};

    for (final expense in expenses) {
      final dateKey = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }

    // Sort by date descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final sortedGrouped = <DateTime, List<Expense>>{};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
      // Create keys for scrolling
      _dateHeaderKeys.putIfAbsent(key, () => GlobalKey());
    }

    return sortedGrouped;
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('home.delete_expense_title')),
        content: Text(context.tr('home.delete_expense_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<ExpenseProvider>().deleteExpense(expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_deleted')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [ReportScreen] Error deleting expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'home.error_deleting_expense',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final originalCategoryId = expense.categoryId;

    final updatedExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(expense: expense),
      ),
    );

    if (updatedExpense == null || !mounted) return;

    try {
      await context.read<ExpenseProvider>().updateExpense(updatedExpense);

      // Log category correction if category was changed
      if (originalCategoryId != updatedExpense.categoryId) {
        if (mounted) {
          final dataCollectionService = context.read<DataCollectionService>();
          await dataCollectionService.logCategoryCorrection(
            expenseId: updatedExpense.id,
            rawInput: updatedExpense.rawInput,
            description: updatedExpense.description,
            amount: updatedExpense.amount,
            originalCategory: originalCategoryId,
            correctedCategory: updatedExpense.categoryId,
            language: updatedExpense.language,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_updated')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [ReportScreen] Error updating expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'home.error_updating_expense',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExpenseDetailsDialog(Expense expense) {
    final categoryProvider = context.read<CategoryProvider>();
    final appConfig = context.read<AppConfigProvider>();
    final currency = appConfig.currency;
    final categoryData =
        categoryProvider.getCategoryById(expense.categoryId) ??
        categoryProvider.getCategoryById('other') ??
        QuickCategory.getDefaultSystemCategories(
          appConfig.language,
        ).firstWhere((c) => c.id == 'other');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(categoryData.icon, color: categoryData.color),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                expense.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              context.tr('home.amount'),
              expense.getFormattedAmount(currency: currency),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(context.tr('home.category'), categoryData.name),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.date'),
              DateFormat.yMMMd(
                context.locale.languageCode,
              ).format(expense.date),
            ),
            if (expense.rawInput.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              _buildDetailRow(
                context.tr('home.original_input'),
                expense.rawInput,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.close')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editExpense(expense);
            },
            icon: const Icon(Icons.edit),
            label: Text(context.tr('common.edit')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(context.tr('navigation.transactions')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: context.tr('navigation.settings'),
          ),
        ],
      ),
      body: Consumer2<ExpenseProvider, AppConfigProvider>(
        builder: (context, expenseProvider, configProvider, _) {
          if (expenseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allExpenses = expenseProvider.expenses;
          final monthExpenses = _getExpensesForMonth(allExpenses);
          final currency = configProvider.currency;

          // Calculate monthly totals
          double monthIncome = 0;
          double monthExpense = 0;
          for (final expense in monthExpenses) {
            if (expense.isIncome) {
              monthIncome += expense.amount;
            } else {
              monthExpense += expense.amount;
            }
          }

          // Group expenses by date
          final groupedExpenses = _groupExpensesByDate(monthExpenses);

          return SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Month Navigator
                MonthNavigator(
                  selectedMonth: _selectedMonth,
                  onMonthChanged: _onMonthChanged,
                ),

                // Calendar Grid
                CalendarGrid(
                  selectedMonth: _selectedMonth,
                  expenses: allExpenses,
                  selectedDate: _selectedDate,
                  onDayTap: _onDayTap,
                  currency: currency,
                ),

                // Monthly Summary Card
                MonthlySummaryCard(
                  income: monthIncome,
                  expense: monthExpense,
                  currency: currency,
                ),

                // Empty state or expense list
                if (groupedExpenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: EmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: context.tr('calendar.no_expenses_this_month'),
                      message: context.tr('calendar.no_expenses_message'),
                    ),
                  )
                else
                  // Grouped expense list
                  ...groupedExpenses.entries.map((entry) {
                    final date = entry.key;
                    final expenses = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date section header
                        DateSectionHeader(
                          key: _dateHeaderKeys[date],
                          date: date,
                        ),

                        // Expenses for this date
                        ...expenses.map((expense) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing16,
                              vertical: AppTheme.spacing4,
                            ),
                            child: Slidable(
                              key: ValueKey(expense.id),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) =>
                                        _deleteExpense(expense.id),
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: context.tr('common.delete'),
                                  ),
                                ],
                              ),
                              child: ExpenseCard(
                                expense: expense,
                                onTap: () => _showExpenseDetailsDialog(expense),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: AppTheme.spacing8),
                      ],
                    );
                  }),

                // Bottom padding
                const SizedBox(height: AppTheme.spacing64),
              ],
            ),
          );
        },
      ),
    );
  }
}

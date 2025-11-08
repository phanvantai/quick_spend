import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/expense_provider.dart';
import '../providers/app_config_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/expense_card.dart';
import '../widgets/edit_expense_dialog.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/home/home_summary_card.dart';
import '../widgets/report/top_expenses_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'settings_screen.dart';
import 'all_expenses_screen.dart';

/// Home Screen showing quick summary and recent expenses
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      debugPrint('❌ [HomeScreen] Error deleting expense: $e');
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
    final updatedExpense = await showDialog<Expense>(
      context: context,
      builder: (context) => EditExpenseDialog(expense: expense),
    );

    if (updatedExpense == null || !mounted) return;

    try {
      await context.read<ExpenseProvider>().updateExpense(updatedExpense);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_updated')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error updating expense: $e');
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

  Future<void> _addExpense() async {
    final newExpense = await showDialog<Expense>(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );

    if (newExpense == null || !mounted) return;

    try {
      await context.read<ExpenseProvider>().addExpense(newExpense);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_added')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error adding expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'home.error_adding_expense',
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
    final categoryData = Category.getByType(expense.category);
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
              expense.getFormattedAmount(),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.category'),
              categoryData.getLabel(expense.language),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.date'),
              DateFormat.yMMMd().add_jm().format(expense.date),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.language'),
              expense.language == 'vi'
                  ? context.tr('home.language_vietnamese')
                  : context.tr('home.language_english'),
            ),
            if (expense.rawInput.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              _buildDetailRow(
                context.tr('home.original_input'),
                expense.rawInput,
              ),
            ],
            if (expense.confidence < 0.8) ...[
              const SizedBox(height: AppTheme.spacing12),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppTheme.warning,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        context.tr(
                          'home.low_confidence_percent',
                          namedArgs: {
                            'percent': (expense.confidence * 100)
                                .toStringAsFixed(0),
                          },
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
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

  // Calculate period totals
  double _getTodayTotal(List<Expense> expenses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expenses
        .where((e) => e.date.isAfter(today))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getWeekTotal(List<Expense> expenses) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return expenses
        .where((e) => e.date.isAfter(weekAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getMonthTotal(List<Expense> expenses) {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return expenses
        .where((e) => e.date.isAfter(monthAgo))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  String _formatAmount(BuildContext context, double amount, String currency) {
    if (currency == 'VND') {
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}${context.tr('currency.suffix_million')}';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(0)}${context.tr('currency.suffix_thousand')}';
      }
      return amount.toStringAsFixed(0);
    } else {
      return '${context.tr('currency.symbol_usd')}${amount.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('home.hello')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addExpense,
            tooltip: context.tr('home.add_expense_tooltip'),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.primaryMint,
            ),
          ),
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

          final expenses = expenseProvider.expenses;
          final currency = configProvider.currency;

          if (expenses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: context.tr('home.no_expenses_title'),
                message: context.tr('home.no_expenses_message'),
              ),
            );
          }

          // Calculate totals
          final todayTotal = _getTodayTotal(expenses);
          final weekTotal = _getWeekTotal(expenses);
          final monthTotal = _getMonthTotal(expenses);

          // Get recent expenses (last 10)
          final recentExpenses = expenses.take(10).toList();

          return CustomScrollView(
            slivers: [
              // Summary Cards Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('home.quick_summary'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            HomeSummaryCard(
                              title: context.tr('home.today'),
                              value: _formatAmount(context, todayTotal, currency),
                              icon: Icons.today_outlined,
                              color: AppTheme.accentOrange,
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            HomeSummaryCard(
                              title: context.tr('home.this_week'),
                              value: _formatAmount(context, weekTotal, currency),
                              icon: Icons.calendar_view_week_outlined,
                              color: AppTheme.accentTeal,
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            HomeSummaryCard(
                              title: context.tr('home.this_month'),
                              value: _formatAmount(context, monthTotal, currency),
                              icon: Icons.calendar_month_outlined,
                              color: AppTheme.primaryMint,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Expenses Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                    AppTheme.spacing16,
                    AppTheme.spacing12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('home.recent_expenses'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (expenses.length > 10)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllExpensesScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(context.tr('home.see_all')),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryMint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Recent Expenses List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  0,
                  AppTheme.spacing16,
                  AppTheme.spacing16,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = recentExpenses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                        child: Slidable(
                          key: ValueKey(expense.id),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (_) => _deleteExpense(expense.id),
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
                    },
                    childCount: recentExpenses.length,
                  ),
                ),
              ),

              // Top Expenses Section
              if (expenses.length >= 5)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.spacing8),
                        TopExpensesList(
                          expenses: List<Expense>.from(expenses)
                            ..sort((a, b) => b.amount.compareTo(a.amount)),
                          currency: currency,
                          language: configProvider.language,
                          onExpenseTap: _showExpenseDetailsDialog,
                          limit: 5,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

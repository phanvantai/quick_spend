import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/app_config_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/expense_card.dart';
import 'expense_form_screen.dart';
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
  // Filter state
  TransactionType? _selectedFilter; // null means "All"

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
    final updatedExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(expense: expense),
      ),
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
    final newExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (context) => const ExpenseFormScreen(),
      ),
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
    final categoryProvider = context.read<CategoryProvider>();
    final categoryData = categoryProvider.getCategoryById(expense.categoryId) ??
        categoryProvider.getCategoryById('other') ??
        QuickCategory.getDefaultSystemCategories().firstWhere(
          (c) => c.id == 'other',
        );
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
              DateFormat.yMMMd(context.locale.languageCode).format(expense.date),
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

  // Get net balance color based on positive/negative
  Color _getNetBalanceColor(double netBalance) {
    if (netBalance > 0) {
      return AppTheme.success;
    } else if (netBalance < 0) {
      return AppTheme.error;
    } else {
      return AppTheme.neutral50;
    }
  }

  // Get net balance icon based on positive/negative
  IconData _getNetBalanceIcon(double netBalance) {
    if (netBalance > 0) {
      return Icons.trending_up;
    } else if (netBalance < 0) {
      return Icons.trending_down;
    } else {
      return Icons.horizontal_rule;
    }
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

  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_selectedFilter == null) {
      return expenses; // Show all
    }
    return expenses.where((e) => e.type == _selectedFilter).toList();
  }

  Widget _buildSummaryCards(
    BuildContext context,
    double totalIncome,
    double totalExpenses,
    double netBalance,
    String currency,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          HomeSummaryCard(
            title: context.tr('home.total_income'),
            value: _formatAmount(context, totalIncome, currency),
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.success,
          ),
          const SizedBox(width: AppTheme.spacing12),
          HomeSummaryCard(
            title: context.tr('home.total_expenses'),
            value: _formatAmount(context, totalExpenses, currency),
            icon: Icons.shopping_bag_outlined,
            color: AppTheme.error,
          ),
          const SizedBox(width: AppTheme.spacing12),
          HomeSummaryCard(
            title: context.tr('home.net_balance'),
            value: _formatAmount(context, netBalance.abs(), currency),
            icon: _getNetBalanceIcon(netBalance),
            color: _getNetBalanceColor(netBalance),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          FilterChip(
            label: Text(context.tr('home.filter_all')),
            selected: _selectedFilter == null,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = null;
              });
            },
            selectedColor: AppTheme.primaryMint.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primaryMint,
          ),
          const SizedBox(width: AppTheme.spacing8),
          FilterChip(
            label: Text(context.tr('home.filter_income')),
            selected: _selectedFilter == TransactionType.income,
            onSelected: (selected) {
              setState(() {
                _selectedFilter =
                    selected ? TransactionType.income : null;
              });
            },
            selectedColor: AppTheme.success.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.success,
          ),
          const SizedBox(width: AppTheme.spacing8),
          FilterChip(
            label: Text(context.tr('home.filter_expense')),
            selected: _selectedFilter == TransactionType.expense,
            onSelected: (selected) {
              setState(() {
                _selectedFilter =
                    selected ? TransactionType.expense : null;
              });
            },
            selectedColor: AppTheme.error.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.error,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<ExpenseProvider, AppConfigProvider>(
        builder: (context, expenseProvider, configProvider, _) {
          if (expenseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = expenseProvider.expenses;
          final currency = configProvider.currency;

          if (expenses.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(context.tr('home.hello')),
                  pinned: true,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: context.tr('home.no_expenses_title'),
                      message: context.tr('home.no_expenses_message'),
                    ),
                  ),
                ),
              ],
            );
          }

          // Get income statistics from provider
          final totalIncome = expenseProvider.totalIncome;
          final totalExpenses = expenseProvider.totalExpenses;
          final netBalance = expenseProvider.netBalance;

          // Apply filter
          final filteredExpenses = _filterExpenses(expenses);

          // Get recent expenses (last 10)
          final recentExpenses = filteredExpenses.take(10).toList();

          return CustomScrollView(
            slivers: [
              // SliverAppBar with summary cards in flexible space
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
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
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        64, // Account for app bar height
                        0,
                        AppTheme.spacing8,
                      ),
                      child: _buildSummaryCards(
                        context,
                        totalIncome,
                        totalExpenses,
                        netBalance,
                        currency,
                      ),
                    ),
                  ),
                ),
              ),

              // Filter chips
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: _buildFilterChips(context),
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
                      if (filteredExpenses.length > 10)
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

/// Delegate for pinned filter header
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _FilterHeaderDelegate({required this.child, this.height = 72.0});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

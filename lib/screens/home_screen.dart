import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/expense_provider.dart';
import '../providers/app_config_provider.dart';
import '../models/expense.dart';
import '../widgets/calendar/month_navigator.dart';
import '../widgets/calendar/monthly_summary_card.dart';
import '../widgets/home/monthly_bar_chart.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import 'expense_form_screen.dart';

/// Home screen with simple, clean UI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  Future<void> _addExpense(BuildContext context) async {
    final newExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(builder: (context) => const ExpenseFormScreen()),
    );

    if (newExpense == null || !context.mounted) return;

    try {
      await context.read<ExpenseProvider>().addExpense(newExpense);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_added')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error adding expense: $e');
      if (context.mounted) {
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

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
  }

  Map<String, double> _calculateMonthlyTotals(List<Expense> expenses) {
    double income = 0;
    double expense = 0;

    for (final exp in expenses) {
      if (exp.date.year == _selectedMonth.year &&
          exp.date.month == _selectedMonth.month) {
        if (exp.type == TransactionType.income) {
          income += exp.amount;
        } else {
          expense += exp.amount;
        }
      }
    }

    return {'income': income, 'expense': expense};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer2<ExpenseProvider, AppConfigProvider>(
        builder: (context, expenseProvider, configProvider, _) {
          final expenses = expenseProvider.expenses;
          final totals = _calculateMonthlyTotals(expenses);

          return CustomScrollView(
            slivers: [
              // App bar with greeting and actions
              SliverAppBar(
                title: Text(context.tr('home.hello')),
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _addExpense(context),
                    tooltip: context.tr('home.add_expense_tooltip'),
                    style: IconButton.styleFrom(
                      foregroundColor: AppTheme.primaryMint,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      );
                    },
                    tooltip: context.tr('navigation.analytics'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    tooltip: context.tr('navigation.settings'),
                  ),
                ],
              ),

              // Month navigator
              SliverToBoxAdapter(
                child: MonthNavigator(
                  selectedMonth: _selectedMonth,
                  onMonthChanged: _onMonthChanged,
                ),
              ),

              // Monthly summary card
              SliverToBoxAdapter(
                child: MonthlySummaryCard(
                  income: totals['income']!,
                  expense: totals['expense']!,
                  appConfig: configProvider.config,
                ),
              ),

              // Monthly bar chart
              SliverToBoxAdapter(
                child: MonthlyBarChart(
                  selectedMonth: _selectedMonth,
                  expenses: expenses,
                  appConfig: configProvider.config,
                ),
              ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacing24),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/report/period_filter.dart';
import '../widgets/report/summary_card.dart';
import '../widgets/report/stats_grid.dart';
import '../widgets/report/category_breakdown_switcher.dart';
import '../widgets/report/top_expenses_list.dart';
import '../widgets/report/custom_date_range_picker.dart';
import '../widgets/common/empty_state.dart';
import '../models/expense.dart';
import 'settings_screen.dart';
import 'expense_form_screen.dart';

/// Home screen showing analytics dashboard with statistics and charts
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer2<ReportProvider, AppConfigProvider>(
        builder: (context, reportProvider, configProvider, _) {
          if (reportProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.tr('report.loading'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final stats = reportProvider.currentStats;

          // Empty state - no expenses at all
          if (stats == null || stats.transactionCount == 0) {
            return CustomScrollView(
              slivers: [
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
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        0,
                        AppTheme.spacing16,
                        AppTheme.spacing16,
                      ),
                      child: PeriodFilter(
                        selectedPeriod: reportProvider.selectedPeriod,
                        onPeriodChanged: (period) {
                          reportProvider.selectPeriod(period);
                        },
                        onCustomTap: () => _showCustomDatePicker(
                          context,
                          reportProvider,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: EmptyState(
                      icon: Icons.bar_chart_outlined,
                      title: context.tr('report.empty_title'),
                      message: context.tr('report.empty_message'),
                    ),
                  ),
                ),
              ],
            );
          }

          // Main dashboard view with data
          return RefreshIndicator(
            onRefresh: () => reportProvider.refresh(),
            child: CustomScrollView(
              slivers: [
                // SliverAppBar with greeting title
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
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        0,
                        AppTheme.spacing16,
                        AppTheme.spacing16,
                      ),
                      child: PeriodFilter(
                        selectedPeriod: reportProvider.selectedPeriod,
                        onPeriodChanged: (period) {
                          reportProvider.selectPeriod(period);
                        },
                        onCustomTap: () => _showCustomDatePicker(
                          context,
                          reportProvider,
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                    AppTheme.spacing16,
                    AppTheme.spacing24,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Summary card
                      SummaryCard(
                        stats: stats,
                        trendPercentage: reportProvider.trendPercentage,
                        isTrendPositive: reportProvider.isTrendPositive,
                        currency: configProvider.currency,
                        language: context.locale.languageCode,
                      ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Stats grid (avg/day, highest expense)
                      StatsGrid(
                        stats: stats,
                        currency: configProvider.currency,
                        language: context.locale.languageCode,
                      ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Category breakdown with expense/income switcher
                      if (stats.expenseCategoryBreakdown.isNotEmpty ||
                          stats.incomeCategoryBreakdown.isNotEmpty)
                        CategoryBreakdownSwitcher(
                          expenseCategoryStats: stats.expenseCategoryBreakdown,
                          incomeCategoryStats: stats.incomeCategoryBreakdown,
                          currency: configProvider.currency,
                          language: context.locale.languageCode,
                        ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Top expenses list
                      if (reportProvider.topExpenses.isNotEmpty)
                        TopExpensesList(
                          expenses: reportProvider.topExpenses,
                          currency: configProvider.currency,
                          language: context.locale.languageCode,
                          limit: 5,
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Show custom date range picker dialog
  Future<void> _showCustomDatePicker(
    BuildContext context,
    ReportProvider reportProvider,
  ) async {
    final dateRange = await CustomDateRangePicker.show(
      context,
      initialStartDate: reportProvider.customDateRange?.start,
      initialEndDate: reportProvider.customDateRange?.end,
    );

    if (dateRange != null) {
      reportProvider.setCustomDateRange(dateRange.start, dateRange.end);
    }
  }
}

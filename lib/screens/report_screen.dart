import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/report_provider.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/report/period_filter.dart';
import '../widgets/report/summary_card.dart';
import '../widgets/report/stats_grid.dart';
import '../widgets/report/category_donut_chart.dart';
import '../widgets/report/category_list.dart';
import '../widgets/report/spending_trend_chart.dart';
import '../widgets/report/top_expenses_list.dart';
import '../widgets/report/custom_date_range_picker.dart';
import '../widgets/common/empty_state.dart';

/// Report screen for viewing expense statistics and charts
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(context.tr('navigation.report')),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              context.read<ReportProvider>().refresh();
            },
            tooltip: context.tr('report.refresh_tooltip'),
          ),
        ],
      ),
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
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Period filter (still show even when empty)
                  PeriodFilter(
                    selectedPeriod: reportProvider.selectedPeriod,
                    onPeriodChanged: (period) {
                      reportProvider.selectPeriod(period);
                    },
                    onCustomTap: () => _showCustomDatePicker(
                      context,
                      reportProvider,
                    ),
                  ),
                  // Empty state
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: EmptyState(
                      icon: Icons.bar_chart_outlined,
                      title: context.tr('report.empty_title'),
                      message: context.tr('report.empty_message'),
                    ),
                  ),
                ],
              ),
            );
          }

          // Main report view with data
          return RefreshIndicator(
            onRefresh: () => reportProvider.refresh(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
              children: [
                // Period filter
                PeriodFilter(
                  selectedPeriod: reportProvider.selectedPeriod,
                  onPeriodChanged: (period) {
                    reportProvider.selectPeriod(period);
                  },
                  onCustomTap: () => _showCustomDatePicker(
                    context,
                    reportProvider,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary card with trend
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

                      // Category donut chart
                      if (stats.categoryBreakdown.isNotEmpty)
                        CategoryDonutChart(
                          categoryStats: stats.categoryBreakdown,
                          language: context.locale.languageCode,
                        ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Category list with progress bars
                      if (stats.categoryBreakdown.isNotEmpty)
                        CategoryList(
                          categoryStats: stats.categoryBreakdown,
                          currency: configProvider.currency,
                          language: context.locale.languageCode,
                        ),
                      const SizedBox(height: AppTheme.spacing16),

                      // Spending trend chart
                      if (stats.dailySpending.isNotEmpty)
                        SpendingTrendChart(
                          stats: stats,
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
                    ],
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

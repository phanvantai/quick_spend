import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../models/expense.dart';
import '../../models/app_config.dart';

/// Simple bar chart showing total income vs expense for a month using fl_chart
class MonthlyBarChart extends StatelessWidget {
  final DateTime selectedMonth;
  final List<Expense> expenses;
  final AppConfig appConfig;

  const MonthlyBarChart({
    super.key,
    required this.selectedMonth,
    required this.expenses,
    required this.appConfig,
  });

  Map<String, double> _calculateMonthlyTotals() {
    double income = 0;
    double expense = 0;

    for (final exp in expenses) {
      if (exp.date.year == selectedMonth.year &&
          exp.date.month == selectedMonth.month) {
        if (exp.type == TransactionType.income) {
          income += exp.amount;
        } else {
          expense += exp.amount;
        }
      }
    }

    return {'income': income, 'expense': expense};
  }

  String _formatAmount(BuildContext context, double amount) {
    // Currencies without decimals: VND, JPY, KRW
    final useDecimals =
        appConfig.currency != 'VND' &&
        appConfig.currency != 'JPY' &&
        appConfig.currency != 'KRW';

    if (!useDecimals) {
      // VND, JPY, KRW - use abbreviated format for large numbers
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}${context.tr('currency.suffix_million')}';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(0)}${context.tr('currency.suffix_thousand')}';
      }
      return amount.toStringAsFixed(0);
    } else {
      // USD, EUR - symbol before value
      // THB - symbol after value
      final symbolAfter = appConfig.currency == 'THB';
      final formatted = amount.toStringAsFixed(0);

      if (symbolAfter) {
        return '$formatted ${appConfig.currencySymbol}';
      } else {
        return '${appConfig.currencySymbol}$formatted';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totals = _calculateMonthlyTotals();
    final income = totals['income']!;
    final expense = totals['expense']!;
    final hasData = income > 0 || expense > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bar chart or empty state
          if (hasData)
            Column(
              children: [
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (income > expense ? income : expense) * 1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        // Income bar
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: income > 0 ? income : 0,
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppTheme.success.withValues(alpha: 0.7),
                                  AppTheme.success,
                                ],
                              ),
                              width: 60,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ],
                          showingTooltipIndicators: [],
                        ),
                        // Expense bar
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: expense > 0 ? expense : 0,
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppTheme.error.withValues(alpha: 0.7),
                                  AppTheme.error,
                                ],
                              ),
                              width: 60,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ],
                          showingTooltipIndicators: [],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                // Labels below chart
                Row(
                  children: [
                    // Income label
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            size: 16,
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('home.filter_income'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Expense label
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_circle,
                            size: 16,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('home.filter_expense'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Empty state
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing32,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Text(
                      context.tr('home.no_data_this_month'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Amount labels below chart
          if (hasData) ...[
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                // Income amount
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _formatAmount(context, income),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Expense amount
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _formatAmount(context, expense),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

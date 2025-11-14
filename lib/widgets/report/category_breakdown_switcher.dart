import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/category_stats.dart';
import '../../models/expense.dart';
import '../../models/app_config.dart';
import '../../theme/app_theme.dart';
import 'category_donut_chart.dart';
import 'category_list.dart';

/// Widget that switches between expense and income category breakdowns
class CategoryBreakdownSwitcher extends StatefulWidget {
  final List<CategoryStats> expenseCategoryStats;
  final List<CategoryStats> incomeCategoryStats;
  final AppConfig appConfig;

  const CategoryBreakdownSwitcher({
    super.key,
    required this.expenseCategoryStats,
    required this.incomeCategoryStats,
    required this.appConfig,
  });

  @override
  State<CategoryBreakdownSwitcher> createState() =>
      _CategoryBreakdownSwitcherState();
}

class _CategoryBreakdownSwitcherState extends State<CategoryBreakdownSwitcher> {
  TransactionType _selectedType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final hasExpenses = widget.expenseCategoryStats.isNotEmpty;
    final hasIncome = widget.incomeCategoryStats.isNotEmpty;

    // If only one type has data, show only that type
    if (!hasExpenses && !hasIncome) {
      return const SizedBox.shrink();
    }

    // Auto-select the type that has data
    if (!hasExpenses && hasIncome) {
      _selectedType = TransactionType.income;
    } else if (hasExpenses && !hasIncome) {
      _selectedType = TransactionType.expense;
    }

    final currentStats = _selectedType == TransactionType.expense
        ? widget.expenseCategoryStats
        : widget.incomeCategoryStats;

    // final title = _selectedType == TransactionType.expense
    //     ? context.tr('report.expense_breakdown')
    //     : context.tr('report.income_breakdown');

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between expense and income (only show if both exist)
            if (hasExpenses && hasIncome) ...[
              Center(
                child: SegmentedButton<TransactionType>(
                  segments: [
                    ButtonSegment<TransactionType>(
                      value: TransactionType.expense,
                      label: Text(context.tr('home.filter_expense')),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    ),
                    ButtonSegment<TransactionType>(
                      value: TransactionType.income,
                      label: Text(context.tr('home.filter_income')),
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                      ),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<TransactionType> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
            ],

            // Donut chart (without card wrapper since we're already in a card)
            if (currentStats.isNotEmpty)
              CategoryDonutChart(
                categoryStats: currentStats,
                language: widget.language,
                title: null, // No title since we have it above
                showCard: false, // Don't show card wrapper
              ),
            const SizedBox(height: AppTheme.spacing16),

            // Category list
            if (currentStats.isNotEmpty)
              CategoryList(
                categoryStats: currentStats,
                appConfig: widget.appConfig,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../models/expense.dart';

/// Calendar grid showing daily income/expense totals
class CalendarGrid extends StatelessWidget {
  final DateTime selectedMonth;
  final List<Expense> expenses;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDayTap;
  final String currency;

  const CalendarGrid({
    super.key,
    required this.selectedMonth,
    required this.expenses,
    this.selectedDate,
    this.onDayTap,
    required this.currency,
  });

  /// Calculate daily totals for the month
  Map<int, DayData> _calculateDailyTotals() {
    final dailyTotals = <int, DayData>{};

    for (final expense in expenses) {
      if (expense.date.year == selectedMonth.year &&
          expense.date.month == selectedMonth.month) {
        final day = expense.date.day;
        final data = dailyTotals.putIfAbsent(
          day,
          () => DayData(income: 0, expense: 0),
        );

        if (expense.isIncome) {
          data.income += expense.amount;
        } else {
          data.expense += expense.amount;
        }
      }
    }

    return dailyTotals;
  }

  /// Get the first day of the month (0 = Sunday, 6 = Saturday)
  int _getFirstWeekday() {
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    return firstDay.weekday % 7; // Convert to 0-indexed (Sunday = 0)
  }

  /// Get number of days in the month
  int _getDaysInMonth() {
    final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return lastDay.day;
  }

  @override
  Widget build(BuildContext context) {
    final dailyTotals = _calculateDailyTotals();
    final firstWeekday = _getFirstWeekday();
    final daysInMonth = _getDaysInMonth();
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
      child: Column(
        children: [
          // Weekday headers
          _buildWeekdayHeaders(context),
          const SizedBox(height: AppTheme.spacing8),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.75,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                // Empty cell before first day of month
                return const SizedBox.shrink();
              }

              final day = index - firstWeekday + 1;
              final date = DateTime(selectedMonth.year, selectedMonth.month, day);
              final dayData = dailyTotals[day];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = selectedDate != null &&
                  date.year == selectedDate!.year &&
                  date.month == selectedDate!.month &&
                  date.day == selectedDate!.day;

              return CalendarDayCell(
                day: day,
                income: dayData?.income ?? 0,
                expense: dayData?.expense ?? 0,
                isToday: isToday,
                isSelected: isSelected,
                hasData: dayData != null,
                onTap: onDayTap != null ? () => onDayTap!(date) : null,
                currency: currency,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    final locale = context.locale.languageCode;
    final weekdays = [
      'calendar.sunday',
      'calendar.monday',
      'calendar.tuesday',
      'calendar.wednesday',
      'calendar.thursday',
      'calendar.friday',
      'calendar.saturday',
    ];

    return Row(
      children: weekdays.map((key) {
        return Expanded(
          child: Center(
            child: Text(
              context.tr(key),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.neutral600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Data for a single day
class DayData {
  double income;
  double expense;

  DayData({required this.income, required this.expense});
}

/// Individual calendar day cell
class CalendarDayCell extends StatelessWidget {
  final int day;
  final double income;
  final double expense;
  final bool isToday;
  final bool isSelected;
  final bool hasData;
  final VoidCallback? onTap;
  final String currency;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.income,
    required this.expense,
    required this.isToday,
    required this.isSelected,
    required this.hasData,
    this.onTap,
    required this.currency,
  });

  String _formatAmount(double amount) {
    if (currency == 'VND') {
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(0)}k';
      }
      return amount.toStringAsFixed(0);
    } else {
      if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(1)}k';
      }
      return amount.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasData ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryMint.withValues(alpha: 0.1)
              : hasData
                  ? Colors.white
                  : Colors.transparent,
          borderRadius: AppTheme.borderRadiusSmall,
          border: Border.all(
            color: isToday
                ? AppTheme.primaryMint
                : hasData
                    ? AppTheme.neutral200
                    : Colors.transparent,
            width: isToday ? 2 : 1,
          ),
          boxShadow: hasData
              ? [
                  BoxShadow(
                    color: AppTheme.neutral900.withValues(alpha: 0.03),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Day number
            Text(
              day.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: isToday
                        ? AppTheme.primaryMint
                        : hasData
                            ? AppTheme.neutral900
                            : AppTheme.neutral400,
                  ),
            ),

            if (hasData) ...[
              const SizedBox(height: 2),

              // Income
              if (income > 0)
                Text(
                  '+${_formatAmount(income)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              // Expense
              if (expense > 0)
                Text(
                  '-${_formatAmount(expense)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

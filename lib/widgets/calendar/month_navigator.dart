import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';

/// Month navigation widget with previous/next buttons
class MonthNavigator extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const MonthNavigator({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  void _previousMonth() {
    final newMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month - 1,
    );
    onMonthChanged(newMonth);
  }

  void _nextMonth() {
    final newMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
    );
    onMonthChanged(newMonth);
  }

  String _getMonthLabel(BuildContext context) {
    final locale = context.locale.languageCode;
    return DateFormat.yMMMM(locale).format(selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous month button
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left),
            tooltip: context.tr('calendar.previous_month'),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.neutral700,
            ),
          ),

          // Month label with today indicator
          Expanded(
            child: GestureDetector(
              onTap: isCurrentMonth
                  ? null
                  : () {
                      // Jump to current month
                      onMonthChanged(DateTime(now.year, now.month));
                    },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getMonthLabel(context),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutral900,
                        ),
                  ),
                  if (!isCurrentMonth) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryMint.withValues(alpha: 0.15),
                        borderRadius: AppTheme.borderRadiusSmall,
                      ),
                      child: Text(
                        context.tr('calendar.today'),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primaryMint,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Next month button
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right),
            tooltip: context.tr('calendar.next_month'),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.neutral700,
            ),
          ),
        ],
      ),
    );
  }
}

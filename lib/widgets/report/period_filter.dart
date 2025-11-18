import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/date_range_helper.dart';
import '../../theme/app_theme.dart';
import '../common/upgrade_prompt_dialog.dart';

/// Period filter widget with tabs for Today/Week/Month/Year/Custom
class PeriodFilter extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final Function(TimePeriod) onPeriodChanged;
  final VoidCallback? onCustomTap;
  final bool isPremium;
  final List<TimePeriod> availablePeriods;

  const PeriodFilter({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.isPremium,
    required this.availablePeriods,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            context,
            TimePeriod.today,
            context.tr(TimePeriod.today.labelKey),
            Icons.today,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisWeek,
            context.tr(TimePeriod.thisWeek.labelKey),
            Icons.date_range,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisMonth,
            context.tr(TimePeriod.thisMonth.labelKey),
            Icons.calendar_month,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisYear,
            context.tr(TimePeriod.thisYear.labelKey),
            Icons.calendar_today,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.custom,
            context.tr(TimePeriod.custom.labelKey),
            Icons.tune,
            onTap: onCustomTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    TimePeriod period,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final isSelected = selectedPeriod == period;
    final isLocked = !availablePeriods.contains(period);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isLocked) {
            // Show upgrade dialog for locked periods
            UpgradePromptDialog.show(
              context,
              title: context.tr('subscription.limit_advanced_reports'),
              message: context.tr(
                'subscription.limit_advanced_reports_message',
                namedArgs: {'limit': '7'},
              ),
              icon: Icons.analytics,
            );
          } else if (onTap != null) {
            onTap();
          } else {
            onPeriodChanged(period);
          }
        },
        borderRadius: AppTheme.borderRadiusMedium,
        child: Opacity(
          opacity: isLocked ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
            decoration: BoxDecoration(
              gradient: isSelected && !isLocked ? AppTheme.summaryGradient : null,
              color: isSelected && !isLocked
                  ? null
                  : colorScheme.surfaceContainerHighest,
              borderRadius: AppTheme.borderRadiusMedium,
              border: isSelected && !isLocked
                  ? null
                  : Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected && !isLocked
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected && !isLocked
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        isSelected && !isLocked ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: AppTheme.spacing4),
                  Icon(
                    Icons.lock,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

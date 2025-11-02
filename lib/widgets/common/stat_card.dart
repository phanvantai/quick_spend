import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Stat card for displaying metrics and statistics
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final String? trend;
  final bool isPositiveTrend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.trend,
    this.isPositiveTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryMint;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.15),
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  child: Icon(icon, color: effectiveColor, size: 20),
                ),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isPositiveTrend ? AppTheme.success : AppTheme.error)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPositiveTrend
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 14,
                          color: isPositiveTrend
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          trend!,
                          style: AppTheme.lightTextTheme.labelSmall?.copyWith(
                            color: isPositiveTrend
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              value,
              style: AppTheme.lightTextTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              title,
              style: AppTheme.lightTextTheme.bodySmall?.copyWith(
                color: AppTheme.neutral600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacing4),
              Text(
                subtitle!,
                style: AppTheme.lightTextTheme.labelSmall?.copyWith(
                  color: AppTheme.neutral500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

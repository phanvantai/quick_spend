import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/period_stats.dart';
import '../../theme/app_theme.dart';

/// Bar chart showing spending trend over time
class SpendingTrendChart extends StatefulWidget {
  final PeriodStats stats;
  final String currency;
  final String language;

  const SpendingTrendChart({
    super.key,
    required this.stats,
    required this.currency,
    required this.language,
  });

  @override
  State<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends State<SpendingTrendChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.stats.dailySpending.isEmpty) {
      return _buildEmptyState(context);
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('report.spending_trend'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.tr('report.daily_spending'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            barTouchResponse == null ||
                            barTouchResponse.spot == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex =
                            barTouchResponse.spot!.touchedBarGroupIndex;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colorScheme.inverseSurface,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      tooltipBorder: const BorderSide(
                        color: Colors.transparent,
                      ),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entries =
                            widget.stats.dailySpending.entries.toList()
                              ..sort((a, b) => a.key.compareTo(b.key));
                        final date = entries[groupIndex].key;
                        final amount = entries[groupIndex].value;

                        return BarTooltipItem(
                          '${DateFormat('MMM d', context.locale.languageCode).format(date)}\n',
                          TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: _formatAmount(context, amount),
                              style: TextStyle(
                                color: colorScheme.onInverseSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) =>
                            _buildBottomTitle(value, meta),
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: _getInterval(),
                        getTitlesWidget: (value, meta) =>
                            _buildLeftTitle(value, meta),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getInterval(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: colorScheme.surfaceContainerHighest,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final entries = widget.stats.dailySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return List.generate(entries.length, (index) {
      final isTouched = index == touchedIndex;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entries[index].value,
            gradient: isTouched
                ? AppTheme.primaryGradient
                : LinearGradient(
                    colors: [
                      AppTheme.primaryMint.withValues(alpha: 0.7),
                      AppTheme.primaryGreen.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
            width: isTouched ? 24 : 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBottomTitle(double value, TitleMeta meta) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final entries = widget.stats.dailySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (value.toInt() >= entries.length) {
      return const SizedBox.shrink();
    }

    final date = entries[value.toInt()].key;
    final text = DateFormat('d', context.locale.languageCode).format(date);

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildLeftTitle(double value, TitleMeta meta) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String text;
    if (widget.language == 'vi') {
      // Vietnamese: Show in thousands (k)
      if (value >= 1000000) {
        text = '${(value / 1000000).toStringAsFixed(0)}${context.tr('currency.suffix_million')}';
      } else if (value >= 1000) {
        text = '${(value / 1000).toStringAsFixed(0)}${context.tr('currency.suffix_thousand')}';
      } else {
        text = value.toStringAsFixed(0);
      }
    } else {
      // English: Show in dollars
      if (value >= 1000) {
        text = '${context.tr('currency.symbol_usd')}${(value / 1000).toStringAsFixed(0)}${context.tr('currency.suffix_thousand')}';
      } else {
        text = '${context.tr('currency.symbol_usd')}${value.toStringAsFixed(0)}';
      }
    }

    return SideTitleWidget(
      meta: meta,
      space: 8,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  double _getMaxY() {
    if (widget.stats.dailySpending.isEmpty) return 100;

    final maxValue = widget.stats.dailySpending.values.reduce(
      (max, value) => value > max ? value : max,
    );

    // Add 20% padding to max value for better visualization
    return maxValue * 1.2;
  }

  double _getInterval() {
    final maxY = _getMaxY();
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    if (maxY <= 1000) return 200;
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 50000) return 10000;
    if (maxY <= 100000) return 20000;
    if (maxY <= 500000) return 100000;
    return 200000;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.tr('report.no_trend_data'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(BuildContext context, double amount) {
    if (widget.language == 'vi') {
      final formatted = amount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return widget.currency == 'VND'
          ? '$formatted${context.tr('currency.symbol_vnd')}'
          : '${context.tr('currency.symbol_usd')}$formatted';
    } else {
      final formatted = amount
          .toStringAsFixed(2)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return widget.currency == 'USD'
          ? '${context.tr('currency.symbol_usd')}$formatted'
          : '$formatted ${context.tr('currency.symbol_vnd')}';
    }
  }
}

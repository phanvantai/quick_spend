import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/category_stats.dart';
import '../../theme/app_theme.dart';

/// Donut chart showing category breakdown
class CategoryDonutChart extends StatefulWidget {
  final List<CategoryStats> categoryStats;
  final String language;
  final String? title;
  final bool showCard;

  const CategoryDonutChart({
    super.key,
    required this.categoryStats,
    required this.language,
    this.title,
    this.showCard = true,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.categoryStats.isEmpty) {
      return _buildEmptyState(context);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Text(
            widget.title!,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (widget.title != null) const SizedBox(height: AppTheme.spacing24),
        LayoutBuilder(
          builder: (context, constraints) {
            // Use the available width to determine chart size
            // Limit max chart size to prevent overflow on large screens (iPad)
            final maxChartSize = constraints.maxWidth > 600 ? 250.0 : 200.0;
            final calculatedChartSize = constraints.maxWidth * 0.65;
            final chartSize = calculatedChartSize < maxChartSize
                ? calculatedChartSize
                : maxChartSize;
            final legendWidth = constraints.maxWidth * 0.30; // 30% for legend

            return SizedBox(
              height: chartSize, // Match height to chartSize to prevent overflow
              child: Row(
                children: [
                  // Donut Chart
                  SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: chartSize / 4.5,
                        sections: _buildPieChartSections(chartSize),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  // Legend
                  SizedBox(width: legendWidth, child: _buildLegend(context)),
                ],
              ),
            );
          },
        ),
      ],
    );

    if (widget.showCard) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child: content,
        ),
      );
    }

    return content;
  }

  List<PieChartSectionData> _buildPieChartSections(double chartSize) {
    return List.generate(widget.categoryStats.length, (i) {
      final isTouched = i == touchedIndex;
      // Dynamic radius - smaller to fit in container
      final radius = isTouched ? chartSize / 4 : chartSize / 4.5;
      final fontSize = isTouched ? chartSize / 12 : chartSize / 15;
      final stat = widget.categoryStats[i];

      return PieChartSectionData(
        color: stat.color,
        value: stat.totalAmount,
        title: '${stat.percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.categoryStats.length,
      itemBuilder: (context, index) {
        final stat = widget.categoryStats[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: stat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  stat.categoryName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
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
              Icons.pie_chart_outline,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'report.no_category_data'.tr(),
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
}

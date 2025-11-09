import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';

/// Category chip widget for displaying and selecting expense categories
class CategoryChip extends StatelessWidget {
  final QuickCategory category;
  final bool isSelected;
  final VoidCallback? onTap;
  final String language;

  const CategoryChip({
    super.key,
    required this.category,
    required this.language,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = category.getLabel(language);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusSmall,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? category.color.withValues(alpha: 0.15)
                : AppTheme.neutral100,
            borderRadius: AppTheme.borderRadiusSmall,
            border: Border.all(
              color: isSelected ? category.color : AppTheme.neutral300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, color: category.color, size: 18),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: AppTheme.lightTextTheme.labelMedium?.copyWith(
                  color: isSelected ? category.color : AppTheme.neutral700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

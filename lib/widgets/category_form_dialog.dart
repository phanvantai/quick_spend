import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

/// Dialog for adding/editing expense categories
class CategoryFormDialog extends StatefulWidget {
  final QuickCategory? category; // Null for add, non-null for edit

  const CategoryFormDialog({super.key, this.category});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameEnController;
  late TextEditingController _nameViController;
  late TextEditingController _keywordsEnController;
  late TextEditingController _keywordsViController;

  late IconData _selectedIcon;
  late Color _selectedColor;

  // Predefined icons for user selection
  static const List<IconData> _availableIcons = [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.local_cafe,
    Icons.movie,
    Icons.sports_esports,
    Icons.fitness_center,
    Icons.school,
    Icons.work,
    Icons.home,
    Icons.pets,
    Icons.child_care,
    Icons.local_hospital,
    Icons.flight,
    Icons.hotel,
    Icons.beach_access,
    Icons.music_note,
    Icons.book,
    Icons.computer,
    Icons.phone_android,
    Icons.directions_car,
    Icons.two_wheeler,
    Icons.local_shipping,
    Icons.attach_money,
    Icons.credit_card,
    Icons.savings,
  ];

  // Predefined colors for user selection
  static const List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();

    final isEdit = widget.category != null;

    _nameEnController = TextEditingController(
      text: isEdit ? widget.category!.nameEn : '',
    );
    _nameViController = TextEditingController(
      text: isEdit ? widget.category!.nameVi : '',
    );
    _keywordsEnController = TextEditingController(
      text: isEdit ? widget.category!.keywordsEn.join(', ') : '',
    );
    _keywordsViController = TextEditingController(
      text: isEdit ? widget.category!.keywordsVi.join(', ') : '',
    );

    _selectedIcon = isEdit
        ? widget.category!.icon
        : _availableIcons[0];
    _selectedColor = isEdit
        ? widget.category!.color
        : _availableColors[0];
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameViController.dispose();
    _keywordsEnController.dispose();
    _keywordsViController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.category != null;

    return AlertDialog(
      title: Text(
        isEdit
            ? context.tr('categories.edit_category')
            : context.tr('categories.add_category'),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Name (English)
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  labelText: context.tr('categories.name_en'),
                  hintText: 'Food, Transport, etc.',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('categories.name_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Name (Vietnamese)
              TextFormField(
                controller: _nameViController,
                decoration: InputDecoration(
                  labelText: context.tr('categories.name_vi'),
                  hintText: 'Ăn uống, Di chuyển, etc.',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('categories.name_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Keywords (English)
              TextFormField(
                controller: _keywordsEnController,
                decoration: InputDecoration(
                  labelText: context.tr('categories.keywords_en'),
                  hintText: 'food, eat, lunch, dinner',
                  helperText: context.tr('categories.keywords_hint'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('categories.keywords_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Keywords (Vietnamese)
              TextFormField(
                controller: _keywordsViController,
                decoration: InputDecoration(
                  labelText: context.tr('categories.keywords_vi'),
                  hintText: 'ăn, cơm, phở, bún',
                  helperText: context.tr('categories.keywords_hint'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('categories.keywords_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Icon Picker
              Text(
                context.tr('categories.icon'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildIconPicker(),
              const SizedBox(height: AppTheme.spacing24),

              // Color Picker
              Text(
                context.tr('categories.color'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildColorPicker(),
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        TextButton(
          onPressed: _saveCategory,
          child: Text(context.tr('common.save')),
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: AppTheme.spacing8,
          mainAxisSpacing: AppTheme.spacing8,
        ),
        itemCount: _availableIcons.length,
        itemBuilder: (context, index) {
          final icon = _availableIcons[index];
          final isSelected = icon == _selectedIcon;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedIcon = icon;
              });
            },
            borderRadius: AppTheme.borderRadiusSmall,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedColor.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: AppTheme.borderRadiusSmall,
                border: Border.all(
                  color: isSelected
                      ? _selectedColor
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? _selectedColor : null,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: _availableColors.map((color) {
        final isSelected = color == _selectedColor;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Parse keywords (split by comma and trim)
    final keywordsEn = _keywordsEnController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final keywordsVi = _keywordsViController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // Create category
    final category = QuickCategory(
      id: widget.category?.id ??
          _nameEnController.text.toLowerCase().replaceAll(' ', '_'),
      nameEn: _nameEnController.text.trim(),
      nameVi: _nameViController.text.trim(),
      keywordsEn: keywordsEn,
      keywordsVi: keywordsVi,
      iconCodePoint: _selectedIcon.codePoint,
      colorValue: _selectedColor.value,
      isSystem: false, // User-defined categories are never system
      userId: AppConstants.defaultUserId,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, category);
  }
}

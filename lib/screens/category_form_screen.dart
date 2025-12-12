import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

/// Full-screen form for adding/editing expense categories
/// Simplified to single language (user's current language)
class CategoryFormScreen extends StatefulWidget {
  final QuickCategory? category; // Null for add, non-null for edit

  const CategoryFormScreen({super.key, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _keywordsController;

  late IconData _selectedIcon;
  late Color _selectedColor;
  late TransactionType _selectedType;

  // Extended icon library for user selection (60+ icons)
  static const List<IconData> _availableIcons = [
    // Food & Dining
    Icons.restaurant,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.local_pizza,
    Icons.fastfood,
    Icons.lunch_dining,
    Icons.dinner_dining,
    Icons.breakfast_dining,
    Icons.ramen_dining,
    Icons.bakery_dining,
    Icons.icecream,
    Icons.cake,

    // Shopping
    Icons.shopping_cart,
    Icons.shopping_bag,
    Icons.local_mall,
    Icons.storefront,
    Icons.store,
    Icons.local_grocery_store,
    Icons.shopping_basket,

    // Transport
    Icons.directions_car,
    Icons.two_wheeler,
    Icons.local_shipping,
    Icons.local_taxi,
    Icons.directions_bus,
    Icons.train,
    Icons.subway,
    Icons.tram,
    Icons.flight,
    Icons.airport_shuttle,
    Icons.directions_bike,
    Icons.electric_scooter,
    Icons.electric_car,
    Icons.ev_station,
    Icons.local_gas_station,

    // Entertainment & Hobbies
    Icons.movie,
    Icons.theater_comedy,
    Icons.music_note,
    Icons.headphones,
    Icons.sports_esports,
    Icons.sports_soccer,
    Icons.sports_basketball,
    Icons.sports_football,
    Icons.sports_tennis,
    Icons.videogame_asset,
    Icons.casino,
    Icons.celebration,
    Icons.nightlife,

    // Health & Fitness
    Icons.local_hospital,
    Icons.medical_services,
    Icons.medication,
    Icons.vaccines,
    Icons.health_and_safety,
    Icons.fitness_center,
    Icons.self_improvement,
    Icons.spa,
    Icons.healing,

    // Education & Work
    Icons.school,
    Icons.work,
    Icons.business,
    Icons.business_center,
    Icons.book,
    Icons.menu_book,
    Icons.library_books,
    Icons.science,
    Icons.psychology,

    // Technology
    Icons.computer,
    Icons.phone_android,
    Icons.phone_iphone,
    Icons.tablet,
    Icons.laptop,
    Icons.keyboard,
    Icons.mouse,
    Icons.headset,
    Icons.devices,
    Icons.router,

    // Home & Living
    Icons.home,
    Icons.house,
    Icons.apartment,
    Icons.bed,
    Icons.chair,
    Icons.weekend,
    Icons.kitchen,
    Icons.microwave,
    Icons.coffee_maker,
    Icons.countertops,
    Icons.light,
    Icons.light_mode,

    // Bills & Finance
    Icons.attach_money,
    Icons.credit_card,
    Icons.payment,
    Icons.account_balance,
    Icons.account_balance_wallet,
    Icons.savings,
    Icons.receipt,
    Icons.receipt_long,
    Icons.request_quote,

    // Personal Care & Fashion
    Icons.checkroom,
    Icons.watch,
    Icons.diamond,
    Icons.face,
    Icons.face_retouching_natural,

    // Pets & Family
    Icons.pets,
    Icons.child_care,
    Icons.child_friendly,
    Icons.baby_changing_station,
    Icons.family_restroom,

    // Travel & Leisure
    Icons.hotel,
    Icons.beach_access,
    Icons.pool,
    Icons.park,
    Icons.forest,
    Icons.hiking,
    Icons.camera,
    Icons.camera_alt,
    Icons.photo_camera,
    Icons.luggage,
    Icons.backpack,

    // Services
    Icons.local_laundry_service,
    Icons.dry_cleaning,
    Icons.local_car_wash,
    Icons.build,
    Icons.construction,
    Icons.plumbing,
    Icons.electrical_services,
    Icons.home_repair_service,

    // Gifts & Donations
    Icons.card_giftcard,
    Icons.redeem,
    Icons.volunteer_activism,
    Icons.favorite,
    Icons.loyalty,

    // Miscellaneous
    Icons.star,
    Icons.more_horiz,
    Icons.extension,
    Icons.category,
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
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();

    final isEdit = widget.category != null;

    _nameController = TextEditingController(
      text: isEdit ? widget.category!.name : '',
    );
    _keywordsController = TextEditingController(
      text: isEdit ? widget.category!.keywords.join(', ') : '',
    );

    _selectedIcon = isEdit ? widget.category!.icon : _availableIcons[0];
    _selectedColor = isEdit ? widget.category!.color : _availableColors[0];
    _selectedType = isEdit ? widget.category!.type : TransactionType.expense;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.category != null;
    final userLanguage = context.watch<AppConfigProvider>().language;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? context.tr('categories.edit_category')
              : context.tr('categories.add_category'),
        ),
        actions: [
          TextButton(
            onPressed: _saveCategory,
            child: Text(
              context.tr('common.save'),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          children: [
            // Preview Card
            _buildPreviewCard(theme),
            const SizedBox(height: AppTheme.spacing24),

            // Type Selector (Income/Expense)
            Text(
              context.tr('categories.type'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text(context.tr('categories.expense')),
                  icon: const Icon(Icons.shopping_bag_outlined),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text(context.tr('categories.income')),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('categories.name'),
                hintText: userLanguage == 'vi'
                    ? 'Ăn uống, Di chuyển, etc.'
                    : 'Food, Transport, etc.',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('categories.name_required');
                }
                return null;
              },
              onChanged: (_) => setState(() {}), // Update preview
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Keywords Field
            TextFormField(
              controller: _keywordsController,
              decoration: InputDecoration(
                labelText: context.tr('categories.keywords'),
                hintText: userLanguage == 'vi'
                    ? 'ăn, cơm, phở, bún'
                    : 'food, eat, lunch, dinner',
                helperText: context.tr('categories.keywords_hint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
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

            // Keywords Help Section
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      context.tr('categories.keywords_help'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),

            // Icon Picker Section
            Text(
              context.tr('categories.icon'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildIconPicker(),
            const SizedBox(height: AppTheme.spacing32),

            // Color Picker Section
            Text(
              context.tr('categories.color'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildColorPicker(),
            const SizedBox(height: AppTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('categories.preview'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIcon, color: _selectedColor, size: 28),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Text(
                    _nameController.text.isEmpty
                        ? context.tr('categories.category_name_placeholder')
                        : _nameController.text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppTheme.spacing12),
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
                  color: isSelected ? _selectedColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? _selectedColor : null,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: AppTheme.spacing12,
      runSpacing: AppTheme.spacing12,
      children: _availableColors.map((color) {
        final isSelected = color == _selectedColor;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
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
    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    // Create category
    final category = QuickCategory(
      id: widget.category?.id ??
          _nameController.text.toLowerCase().replaceAll(' ', '_'),
      name: _nameController.text.trim(),
      keywords: keywords,
      iconCodePoint: _selectedIcon.codePoint,
      colorValue: _selectedColor.toARGB32(),
      isSystem: widget.category?.isSystem ?? false,
      userId: AppConstants.defaultUserId,
      type: _selectedType,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, category);
  }
}

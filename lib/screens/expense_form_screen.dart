import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import '../models/expense.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../theme/app_theme.dart';

/// Full screen for adding or editing expenses
class ExpenseFormScreen extends StatefulWidget {
  /// The expense to edit. If null, creates a new expense
  final Expense? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late String _selectedCategoryId;
  late DateTime _selectedDate;
  late TransactionType _selectedType;
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.expense != null;

    _descriptionController = TextEditingController(
      text: widget.expense?.description ?? '',
    );

    // Initialize amount controller with raw number (no pre-formatting)
    // CurrencyInputFormatter will handle formatting automatically
    _amountController = TextEditingController(
      text: widget.expense != null
          ? _formatInitialAmount(widget.expense!.amount)
          : '',
    );

    _selectedType = widget.expense?.type ?? TransactionType.expense;
    _selectedCategoryId = widget.expense?.categoryId ?? 'other';

    // Initialize date: use existing date for edit mode, or today at noon for new expenses
    if (_isEditMode && widget.expense != null) {
      _selectedDate = widget.expense!.date;
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day, 12, 0);
    }
  }

  /// Format initial amount as raw number string (no thousand separators)
  /// CurrencyInputFormatter expects unformatted input and will add separators
  String _formatInitialAmount(double amount) {
    // Return clean number without thousand separators
    // Example: 1000.0 → "1000" (not "1.000")
    if (amount == amount.truncateToDouble()) {
      // No decimal part, return as integer string
      return amount.toStringAsFixed(0);
    } else {
      // Has decimal part, return as-is
      return amount.toString();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        // Set time to noon (12:00) for consistency
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          12,
          0,
        );
      });
    }
  }

  double _parseAmount(String text, String language) {
    // Remove formatting and parse based on locale
    String numericString;
    if (language.startsWith('vi')) {
      // Vietnamese: remove periods (thousand sep), replace comma with period (decimal sep)
      numericString = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // English: remove commas (thousand sep), period is already decimal sep
      numericString = text.replaceAll(',', '');
    }
    return double.tryParse(numericString.trim()) ?? 0.0;
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final language = context.read<AppConfigProvider>().language;
      final userId = context.read<ExpenseProvider>().currentUserId;

      // Parse formatted amount (locale-aware)
      final amount = _parseAmount(_amountController.text, language);

      final expense = Expense(
        id: _isEditMode
            ? widget.expense!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _isEditMode ? widget.expense!.userId : userId,
        amount: amount,
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        language: _isEditMode ? widget.expense!.language : language,
        confidence: _isEditMode ? widget.expense!.confidence : 1.0,
        rawInput: _isEditMode
            ? widget.expense!.rawInput
            : _descriptionController.text.trim(),
        type: _selectedType,
      );

      Navigator.pop(context, expense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appConfig = context.watch<AppConfigProvider>();
    final language = appConfig.language;
    final currency = appConfig.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? context.tr('home.edit_expense')
              : context.tr('home.add_expense'),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              context.tr('common.save'),
              style: TextStyle(
                color: AppTheme.primaryMint,
                fontWeight: FontWeight.w600,
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
            // Transaction type switcher
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text(context.tr('categories.expense')),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text(context.tr('categories.income')),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  // Reset category to first available for the new type
                  final categoryProvider = context.read<CategoryProvider>();
                  final categoriesOfType = categoryProvider.categories
                      .where((cat) => cat.type == _selectedType)
                      .toList();
                  if (categoriesOfType.isNotEmpty) {
                    _selectedCategoryId = categoriesOfType.first.id;
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return _selectedType == TransactionType.expense
                        ? AppTheme.error.withValues(alpha: 0.15)
                        : AppTheme.success.withValues(alpha: 0.15);
                  }
                  return colorScheme.surface;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return _selectedType == TransactionType.expense
                        ? AppTheme.error
                        : AppTheme.success;
                  }
                  return colorScheme.onSurface;
                }),
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.tr('home.description'),
                hintText: context.tr('home.description_hint'),
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEditMode,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('home.description_required');
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing20),

            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: context.tr('home.amount'),
                hintText: '0',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                CurrencyInputFormatter(
                  thousandSeparator: language.startsWith('vi')
                      ? ThousandSeparator.Period
                      : ThousandSeparator.Comma,
                  mantissaLength: currency == 'VND' ? 0 : 2,
                ),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('home.amount_required');
                }
                // Parse formatted value for validation (locale-aware)
                final language = context.read<AppConfigProvider>().language;
                final amount = _parseAmount(value, language);
                if (amount <= 0) {
                  return context.tr('home.amount_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Category selector
            Text(
              context.tr('home.category'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                if (categoryProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter categories by selected transaction type
                final categories = categoryProvider.categories
                    .where((cat) => cat.type == _selectedType)
                    .toList();

                if (categories.isEmpty) {
                  return Text(
                    'No categories available',
                    style: theme.textTheme.bodyMedium,
                  );
                }

                return Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing8,
                  children: categories.map((category) {
                    final isSelected = _selectedCategoryId == category.id;

                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon,
                            size: 18,
                            color: isSelected ? Colors.white : category.color,
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(category.name),
                        ],
                      ),
                      backgroundColor: category.color.withValues(alpha: 0.15),
                      selectedColor: category.color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : category.color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? category.color
                              : category.color.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = category.id;
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Date selector
            Text(
              context.tr('home.date'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: AppTheme.borderRadiusMedium,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Text(
                      DateFormat.yMMMd(
                        context.locale.languageCode,
                      ).format(_selectedDate),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Show confidence warning for low-confidence expenses
            if (_isEditMode && widget.expense!.confidence < 0.8) ...[
              const SizedBox(height: AppTheme.spacing24),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusMedium,
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.warning),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        context.tr(
                          'home.low_confidence_percent',
                          namedArgs: {
                            'percent': (widget.expense!.confidence * 100)
                                .toStringAsFixed(0),
                          },
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

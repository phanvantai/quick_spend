import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.expense != null;

    _descriptionController = TextEditingController(
      text: widget.expense?.description ?? '',
    );
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _selectedCategoryId = widget.expense?.categoryId ?? 'other';

    // Initialize date: use existing date for edit mode, or today at noon for new expenses
    if (_isEditMode && widget.expense != null) {
      _selectedDate = widget.expense!.date;
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day, 12, 0);
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

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final language = context.read<AppConfigProvider>().language;
      final userId = context.read<ExpenseProvider>().currentUserId;

      final expense = Expense(
        id: _isEditMode
            ? widget.expense!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _isEditMode ? widget.expense!.userId : userId,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        language: _isEditMode ? widget.expense!.language : language,
        confidence: _isEditMode ? widget.expense!.confidence : 1.0,
        rawInput: _isEditMode
            ? widget.expense!.rawInput
            : _descriptionController.text.trim(),
      );

      Navigator.pop(context, expense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final language = context.watch<AppConfigProvider>().language;

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
                hintText: '0.00',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('home.amount_required');
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
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

                final categories = categoryProvider.categories;
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
                          Text(category.getLabel(language)),
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
                      DateFormat.yMMMd().format(_selectedDate),
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

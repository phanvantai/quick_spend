import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
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
  late ExpenseCategory _selectedCategory;
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
    _selectedCategory = widget.expense?.category ?? ExpenseCategory.other;
    _selectedDate = widget.expense?.date ?? DateTime.now();
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

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
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
        category: _selectedCategory,
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
        title: Text(_isEditMode
            ? context.tr('home.edit_expense')
            : context.tr('home.add_expense')),
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
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              children: ExpenseCategory.values.map((category) {
                final categoryData = Category.getByType(category);
                final isSelected = _selectedCategory == category;

                return FilterChip(
                  selected: isSelected,
                  label: Text(categoryData.getLabel(language)),
                  avatar: Icon(
                    categoryData.icon,
                    size: 18,
                    color: isSelected ? Colors.white : categoryData.color,
                  ),
                  backgroundColor: categoryData.color.withValues(alpha: 0.1),
                  selectedColor: categoryData.color,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : categoryData.color,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              }).toList(),
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
                      DateFormat.yMMMd().add_jm().format(_selectedDate),
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
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.warning,
                    ),
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

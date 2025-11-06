import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// Dialog for editing an existing expense
class EditExpenseDialog extends StatefulWidget {
  final Expense expense;

  const EditExpenseDialog({
    super.key,
    required this.expense,
  });

  @override
  State<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<EditExpenseDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.expense.description);
    _amountController = TextEditingController(text: widget.expense.amount.toString());
    _selectedCategory = widget.expense.category;
    _selectedDate = widget.expense.date;
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
      final updatedExpense = Expense(
        id: widget.expense.id,
        userId: widget.expense.userId,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        language: widget.expense.language,
        confidence: widget.expense.confidence,
        rawInput: widget.expense.rawInput,
      );

      Navigator.pop(context, updatedExpense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(context.tr('home.edit_expense')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.tr('home.description'),
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.tr('home.description_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Amount field
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: context.tr('home.amount'),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: AppTheme.spacing16),

              // Category selector
              Text(
                context.tr('home.category'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: ExpenseCategory.values.map((category) {
                  final categoryData = Category.getByType(category);
                  final isSelected = _selectedCategory == category;

                  return FilterChip(
                    selected: isSelected,
                    label: Text(categoryData.getLabel(widget.expense.language)),
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Date selector
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today, color: colorScheme.primary),
                title: Text(context.tr('home.date')),
                subtitle: Text(
                  DateFormat.yMMMd().add_jm().format(_selectedDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMedium,
                  side: BorderSide(color: colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.tr('common.save')),
        ),
      ],
    );
  }
}

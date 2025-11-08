import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';

/// Dialog for adding a new expense manually
class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
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
        // ignore: use_build_context_synchronously
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
      final newExpense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'default_user',
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        language: language,
        confidence: 1.0, // Manual entry has perfect confidence
        rawInput: _descriptionController.text.trim(),
      );

      Navigator.pop(context, newExpense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final language = context.watch<AppConfigProvider>().language;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppTheme.primaryMint),
          const SizedBox(width: AppTheme.spacing8),
          Text(context.tr('home.add_expense')),
        ],
      ),
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
                  hintText: context.tr('home.description_hint'),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
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
                  hintText: '0.00',
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
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add),
          label: Text(context.tr('common.add')),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryMint,
          ),
        ),
      ],
    );
  }
}

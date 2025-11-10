import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/expense_parser.dart';
import '../../theme/app_theme.dart';

/// Editable expense confirmation dialog
class EditableExpenseDialog extends StatefulWidget {
  final List<ParseResult> results;

  const EditableExpenseDialog({super.key, required this.results});

  @override
  State<EditableExpenseDialog> createState() => _EditableExpenseDialogState();
}

class _EditableExpenseDialogState extends State<EditableExpenseDialog> {
  late List<_ExpenseFormData> _expenseForms;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize form data from parsed results
    _expenseForms = widget.results
        .map((r) => _ExpenseFormData.fromExpense(r.expense!))
        .toList();
  }

  Future<void> _saveExpenses() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    debugPrint(
      '💾 [EditableExpenseDialog] Saving ${_expenseForms.length} expense(s)',
    );

    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();

    try {
      final expenses = _expenseForms.map((form) => form.toExpense()).toList();

      await expenseProvider.addExpenses(expenses);

      debugPrint('✅ [EditableExpenseDialog] Expenses saved successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expenses.length > 1
                  ? context.tr(
                      'home.expenses_saved_multiple',
                      namedArgs: {'count': expenses.length.toString()},
                    )
                  : context.tr('home.expense_saved_single'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [EditableExpenseDialog] Error saving expenses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'home.error_saving_expenses',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _expenseForms.length > 1
            ? context.tr(
                'home.expenses_parsed_multiple',
                namedArgs: {'count': _expenseForms.length.toString()},
              )
            : context.tr('home.expense_parsed_single'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _expenseForms.length; i++) ...[
                if (_expenseForms.length > 1) ...[
                  Text(
                    context.tr(
                      'home.expense_number',
                      namedArgs: {'number': (i + 1).toString()},
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                ],
                _ExpenseFormCard(
                  formData: _expenseForms[i],
                  onChanged: () => setState(() {}),
                ),
                if (i < _expenseForms.length - 1) ...[
                  const Divider(height: AppTheme.spacing24),
                ],
              ],
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
          onPressed: _saveExpenses,
          icon: const Icon(Icons.check),
          label: Text(context.tr('common.save')),
        ),
      ],
    );
  }
}

/// Form card for editing a single expense
class _ExpenseFormCard extends StatelessWidget {
  final _ExpenseFormData formData;
  final VoidCallback onChanged;

  const _ExpenseFormCard({required this.formData, required this.onChanged});

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: formData.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != formData.date) {
      formData.date = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final appConfig = context.watch<AppConfigProvider>().config;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transaction type switcher
        SegmentedButton<TransactionType>(
          segments: [
            ButtonSegment<TransactionType>(
              value: TransactionType.expense,
              label: Text(context.tr('categories.expense')),
              icon: const Icon(Icons.remove_circle_outline, size: 18),
            ),
            ButtonSegment<TransactionType>(
              value: TransactionType.income,
              label: Text(context.tr('categories.income')),
              icon: const Icon(Icons.add_circle_outline, size: 18),
            ),
          ],
          selected: {formData.type},
          onSelectionChanged: (Set<TransactionType> newSelection) {
            formData.type = newSelection.first;
            // Reset category to first available for the new type
            final categoriesOfType = categoryProvider.categories
                .where((cat) => cat.type == formData.type)
                .toList();
            if (categoriesOfType.isNotEmpty) {
              formData.categoryId = categoriesOfType.first.id;
            }
            onChanged();
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return formData.type == TransactionType.expense
                      ? AppTheme.error.withValues(alpha: 0.15)
                      : AppTheme.success.withValues(alpha: 0.15);
                }
                return colorScheme.surface;
              },
            ),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return formData.type == TransactionType.expense
                      ? AppTheme.error
                      : AppTheme.success;
                }
                return colorScheme.onSurface;
              },
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Description field
        TextFormField(
          initialValue: formData.description,
          decoration: InputDecoration(
            labelText: context.tr('home.description'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.description_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.tr('home.description_required');
            }
            return null;
          },
          onSaved: (value) => formData.description = value!.trim(),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Amount field
        TextFormField(
          initialValue: formData.amount.toString(),
          decoration: InputDecoration(
            labelText: context.tr('home.amount'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
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
          onSaved: (value) => formData.amount = double.parse(value!),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Category selector (filtered by transaction type)
        DropdownButtonFormField<String>(
          initialValue: formData.categoryId,
          decoration: InputDecoration(
            labelText: context.tr('home.category'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: categoryProvider.categories
              .where((cat) => cat.type == formData.type) // Filter by transaction type
              .map((cat) {
            return DropdownMenuItem(
              value: cat.id,
              child: Row(
                children: [
                  Icon(cat.icon, color: cat.color, size: 20),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(cat.getLabel(appConfig.language)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              formData.categoryId = value;
              onChanged();
            }
          },
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Date selector
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.tr('home.date'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              DateFormat.yMMMd(context.locale.languageCode).format(formData.date),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),

        // Low confidence warning
        if (formData.confidence < 0.7) ...[
          const SizedBox(height: AppTheme.spacing12),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: AppTheme.borderRadiusSmall,
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_outlined,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.tr('home.low_confidence_verify'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Data class to hold expense form data
class _ExpenseFormData {
  String id;
  String description;
  double amount;
  String categoryId;
  String language;
  DateTime date;
  String userId;
  String rawInput;
  double confidence;
  TransactionType type;

  _ExpenseFormData({
    required this.id,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.language,
    required this.date,
    required this.userId,
    required this.rawInput,
    required this.confidence,
    required this.type,
  });

  factory _ExpenseFormData.fromExpense(Expense expense) {
    return _ExpenseFormData(
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      categoryId: expense.categoryId,
      language: expense.language,
      date: expense.date,
      userId: expense.userId,
      rawInput: expense.rawInput,
      confidence: expense.confidence,
      type: expense.type,
    );
  }

  Expense toExpense() {
    return Expense(
      id: id,
      description: description,
      amount: amount,
      categoryId: categoryId,
      language: language,
      date: date,
      userId: userId,
      rawInput: rawInput,
      confidence: confidence,
      type: type,
    );
  }
}

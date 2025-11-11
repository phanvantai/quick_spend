import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import '../models/expense.dart';
import '../models/recurring_expense_template.dart';
import '../models/recurrence_pattern.dart';
import '../providers/recurring_template_provider.dart';
import '../providers/category_provider.dart';
import '../providers/app_config_provider.dart';
import '../theme/app_theme.dart';

/// Screen for adding or editing a recurring expense template
class RecurringExpenseFormScreen extends StatefulWidget {
  final RecurringExpenseTemplate? template; // null for add, non-null for edit
  final String userId;

  const RecurringExpenseFormScreen({
    super.key,
    this.template,
    required this.userId,
  });

  @override
  State<RecurringExpenseFormScreen> createState() =>
      _RecurringExpenseFormScreenState();
}

class _RecurringExpenseFormScreenState
    extends State<RecurringExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  late TransactionType _type;
  String? _categoryId;
  late RecurrencePattern _pattern;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _hasEndDate = false;

  @override
  void initState() {
    super.initState();

    // Initialize with existing template or defaults
    if (widget.template != null) {
      final template = widget.template!;
      _descriptionController.text = template.description;
      // Initialize amount controller (will format after first build)
      _amountController.text = template.amount.toString();
      _type = template.type;
      _categoryId = template.categoryId;
      _pattern = template.pattern;
      _startDate = template.startDate;
      _endDate = template.endDate;
      _hasEndDate = template.endDate != null;

      // Format amount after first build when we have access to language
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final language = context.read<AppConfigProvider>().config.language;
          final formattedAmount = toCurrencyString(
            template.amount.toString(),
            mantissaLength: 2,
            thousandSeparator: language.startsWith('vi')
                ? ThousandSeparator.Period
                : ThousandSeparator.Comma,
          );
          _amountController.text = formattedAmount;
        }
      });
    } else {
      _type = TransactionType.expense;
      _pattern = RecurrencePattern.monthly;
      _startDate = DateTime.now();
      _endDate = null;
      _hasEndDate = false;

      // Set default category for expense type
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final categoryProvider = context.read<CategoryProvider>();
          final categories = categoryProvider.categories
              .where((cat) => cat.type == _type)
              .toList();
          if (categories.isNotEmpty && _categoryId == null) {
            setState(() {
              _categoryId = categories.first.id;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date exists and is before start date, clear it
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Ensure category is selected
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('home.category_required')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    final templateProvider = context.read<RecurringTemplateProvider>();
    final appConfig = context.read<AppConfigProvider>().config;

    try {
      // Parse formatted amount (removes thousand separators)
      final amountString = toNumericString(_amountController.text);
      final amount = double.tryParse(amountString) ?? 0.0;

      final template = RecurringExpenseTemplate(
        id: widget.template?.id ?? const Uuid().v4(),
        amount: amount,
        description: _descriptionController.text.trim(),
        categoryId: _categoryId!,
        language: appConfig.language,
        userId: widget.userId,
        type: _type,
        pattern: _pattern,
        startDate: _startDate,
        endDate: _hasEndDate ? _endDate : null,
        lastGeneratedDate: widget.template?.lastGeneratedDate,
        isActive: widget.template?.isActive ?? true,
      );

      if (widget.template == null) {
        await templateProvider.addTemplate(template);
      } else {
        await templateProvider.updateTemplate(template);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.template == null
                  ? context.tr('recurring.template_added')
                  : context.tr('recurring.template_updated'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        '❌ [RecurringExpenseFormScreen] Error saving template: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'recurring.error_saving',
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
    final categoryProvider = context.watch<CategoryProvider>();
    final appConfig = context.watch<AppConfigProvider>().config;
    final language = appConfig.language;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.template == null
              ? context.tr('recurring.add_template')
              : context.tr('recurring.edit_template'),
        ),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: Text(
              context.tr('common.save'),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text(context.tr('categories.income')),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  // Reset category to first available for the new type
                  final categoriesOfType = categoryProvider.categories
                      .where((cat) => cat.type == _type)
                      .toList();
                  if (categoriesOfType.isNotEmpty) {
                    _categoryId = categoriesOfType.first.id;
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return _type == TransactionType.expense
                        ? AppTheme.error.withValues(alpha: 0.15)
                        : AppTheme.success.withValues(alpha: 0.15);
                  }
                  return colorScheme.surface;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return _type == TransactionType.expense
                        ? AppTheme.error
                        : AppTheme.success;
                  }
                  return colorScheme.onSurface;
                }),
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Description field
            TextFormField(
              controller: _descriptionController,
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
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: context.tr('home.amount'),
                hintText: '0',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                CurrencyInputFormatter(
                  thousandSeparator: language.startsWith('vi')
                      ? ThousandSeparator.Period
                      : ThousandSeparator.Comma,
                  mantissaLength: 2,
                ),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('home.amount_required');
                }
                // Parse formatted value for validation
                final numericString = toNumericString(value);
                final amount = double.tryParse(numericString);
                if (amount == null || amount <= 0) {
                  return context.tr('home.amount_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Category selector (filtered by transaction type)
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: InputDecoration(
                labelText: context.tr('home.category'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: categoryProvider.categories
                  .where((cat) => cat.type == _type)
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
                  })
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _categoryId = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Recurrence pattern selector
            DropdownButtonFormField<RecurrencePattern>(
              value: _pattern,
              decoration: InputDecoration(
                labelText: context.tr('recurring.pattern'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.repeat),
              ),
              items: [RecurrencePattern.monthly, RecurrencePattern.yearly]
                  .map((pattern) {
                    return DropdownMenuItem(
                      value: pattern,
                      child: Text(pattern.getDescription(appConfig.language)),
                    );
                  })
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _pattern = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Start date selector
            InkWell(
              onTap: _selectStartDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('recurring.start_date'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  DateFormat.yMMMd(appConfig.language).format(_startDate),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // End date toggle and selector
            CheckboxListTile(
              title: Text(context.tr('recurring.has_end_date')),
              value: _hasEndDate,
              onChanged: (value) {
                setState(() {
                  _hasEndDate = value ?? false;
                  if (!_hasEndDate) {
                    _endDate = null;
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_hasEndDate) ...[
              const SizedBox(height: AppTheme.spacing8),
              InkWell(
                onTap: _selectEndDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('recurring.end_date'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.event),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat.yMMMd(
                            appConfig.language,
                          ).format(_endDate!)
                        : context.tr('recurring.select_end_date'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

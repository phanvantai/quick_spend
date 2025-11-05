import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/expense_card.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Home Screen with modern UI and voice input
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  double _soundLevel = 0.0;
  String _recognizedText = '';

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [HomeScreen] Starting recording...');

    final hasPermission = await _voiceService.hasPermission();
    debugPrint('🔐 [HomeScreen] Has microphone permission: $hasPermission');

    if (!hasPermission) {
      final shouldRequest = await _showPermissionRationale();
      if (!shouldRequest || !mounted) {
        debugPrint('❌ [HomeScreen] User declined permission rationale');
        return;
      }

      final granted = await _voiceService.requestPermission();
      debugPrint('🔐 [HomeScreen] Permission granted: $granted');

      if (!granted) {
        debugPrint('❌ [HomeScreen] Microphone permission denied');
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }
    }

    if (!mounted) return;
    final configProvider = context.read<AppConfigProvider>();
    final language = configProvider.language;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    final success = await _voiceService.startListening(
      language: language,
      onResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
      onSoundLevel: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
    );

    if (!success && mounted) {
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('voice.error')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('🛑 [HomeScreen] Stopping recording...');
    await _voiceService.stopListening();
    setState(() {
      _isRecording = false;
    });

    if (_recognizedText.isNotEmpty) {
      _processExpense(_recognizedText);
    }
  }

  Future<void> _cancelRecording() async {
    debugPrint('❌ [HomeScreen] Canceling recording...');
    await _voiceService.cancelListening();
    setState(() {
      _isRecording = false;
      _recognizedText = '';
    });
  }

  Future<void> _processExpense(String input) async {
    debugPrint('💰 [HomeScreen] Processing expense: "$input"');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  context.tr('home.parsing_expense'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final results = await ExpenseParser.parse(
        input,
        expenseProvider.currentUserId,
      );
      if (mounted) Navigator.pop(context);

      if (results.isEmpty || !results.any((r) => r.success)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('home.parse_failed')),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      final successfulResults = results
          .where((r) => r.success && r.expense != null)
          .toList();
      if (mounted && successfulResults.isNotEmpty) {
        _showExpenseResultsDialog(successfulResults);
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showExpenseResultsDialog(List<ParseResult> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          results.length > 1
              ? context.tr('home.expenses_parsed_multiple', namedArgs: {'count': results.length.toString()})
              : context.tr('home.expense_parsed_single'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < results.length; i++) ...[
                if (results.length > 1) ...[
                  Text(
                    context.tr('home.expense_number', namedArgs: {'number': (i + 1).toString()}),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                ],
                _buildExpenseDetails(results[i]),
                if (i < results.length - 1) ...[
                  const Divider(height: AppTheme.spacing24),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => _saveExpenses(results),
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpenses(List<ParseResult> results) async {
    debugPrint(
      '💾 [HomeScreen] Save button pressed, saving ${results.length} result(s)',
    );

    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();

    try {
      // Save all expenses
      final expenses = results
          .where((r) => r.success && r.expense != null)
          .map((r) => r.expense!)
          .toList();

      debugPrint(
        '💾 [HomeScreen] Filtered to ${expenses.length} valid expense(s)',
      );

      await expenseProvider.addExpenses(expenses);

      debugPrint('✅ [HomeScreen] Expenses saved successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expenses.length > 1
                  ? context.tr('home.expenses_saved_multiple', namedArgs: {'count': expenses.length.toString()})
                  : context.tr('home.expense_saved_single'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error saving expenses: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.error_saving_expenses', namedArgs: {'error': e.toString()})),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('home.delete_expense_title')),
        content: Text(
          context.tr('home.delete_expense_message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<ExpenseProvider>().deleteExpense(expenseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.expense_deleted')),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error deleting expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.error_deleting_expense', namedArgs: {'error': e.toString()})),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExpenseDetailsDialog(Expense expense) {
    final categoryData = Category.getByType(expense.category);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(categoryData.icon, color: categoryData.color),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                expense.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(context.tr('home.amount'), expense.getFormattedAmount()),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.category'),
              categoryData.getLabel(expense.language),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.date'),
              DateFormat.yMMMd().add_jm().format(expense.date),
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildDetailRow(
              context.tr('home.language'),
              expense.language == 'vi' ? context.tr('home.language_vietnamese') : context.tr('home.language_english'),
            ),
            if (expense.rawInput.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              _buildDetailRow(context.tr('home.original_input'), expense.rawInput),
            ],
            if (expense.confidence < 0.8) ...[
              const SizedBox(height: AppTheme.spacing12),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppTheme.warning,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        context.tr('home.low_confidence_percent', namedArgs: {'percent': (expense.confidence * 100).toStringAsFixed(0)}),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseDetails(ParseResult result) {
    final expense = result.expense!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${context.tr('home.amount')}: ${expense.getFormattedAmount()}'),
        Text('${context.tr('home.description')}: ${expense.description}'),
        Text('${context.tr('home.category')}: ${expense.category.toString().split('.').last}'),
        if (result.overallConfidence != null && result.overallConfidence! < 0.7)
          Text(
            '\n${context.tr('home.low_confidence_verify')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Consumer<AppConfigProvider>(
      builder: (context, configProvider, _) {
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Stack(
            children: [
              // Main content
              CustomScrollView(
                slivers: [
                  // App bar with gradient
                  SliverAppBar(
                    expandedHeight: 160,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppTheme.primaryMint,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(height: AppTheme.spacing12),
                                Text(
                                  context.tr('home.welcome'),
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content - Expense List
                  Consumer<ExpenseProvider>(
                    builder: (context, expenseProvider, _) {
                      if (expenseProvider.isLoading) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final expenses = expenseProvider.expenses;

                      if (expenses.isEmpty) {
                        return SliverPadding(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: context.tr('home.no_expenses_title'),
                                message:
                                    context.tr('home.no_expenses_message'),
                                actionLabel: context.tr('home.add_expense'),
                                onAction: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.tr('voice.hold_instruction'),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ]),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final expense = expenses[index];
                            return Slidable(
                              key: ValueKey(expense.id),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) =>
                                        _deleteExpense(expense.id),
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: context.tr('common.delete'),
                                  ),
                                ],
                              ),
                              child: ExpenseCard(
                                expense: expense,
                                onTap: () => _showExpenseDetailsDialog(expense),
                              ),
                            );
                          }, childCount: expenses.length),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Recording overlay
              if (_isRecording)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated microphone
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: _soundLevel),
                          duration: const Duration(milliseconds: 100),
                          builder: (context, value, child) {
                            final normalizedLevel = ((value + 60) / 40).clamp(
                              0.0,
                              1.0,
                            );
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildRipple(normalizedLevel, 180, 0.2),
                                _buildRipple(normalizedLevel, 150, 0.3),
                                Container(
                                  width: 100.0 + (normalizedLevel * 30.0),
                                  height: 100.0 + (normalizedLevel * 30.0),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.accentGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentPink.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 20 + (normalizedLevel * 10),
                                        spreadRadius: 5 + (normalizedLevel * 5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.mic,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppTheme.spacing24),
                        Text(
                          context.tr('voice.listening'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (_recognizedText.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spacing16),
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing32,
                            ),
                            padding: const EdgeInsets.all(AppTheme.spacing16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppTheme.borderRadiusMedium,
                              boxShadow: AppTheme.shadowLarge,
                            ),
                            child: Text(
                              _recognizedText,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spacing32),
                        Text(
                          context.tr('voice.slide_to_cancel'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Voice FAB
          floatingActionButton: _buildVoiceFAB(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildVoiceFAB() {
    return GestureDetector(
      onLongPressStart: _isRecording ? null : (_) => _startRecording(),
      onLongPressEnd: _isRecording ? (_) => _stopRecording() : null,
      onVerticalDragUpdate: _isRecording
          ? (details) {
              if (details.primaryDelta! < -10) {
                _cancelRecording();
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: _isRecording
              ? AppTheme.accentGradient
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isRecording
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('voice.hold_instruction')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
                vertical: AppTheme.spacing16,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    _isRecording ? context.tr('home.recording') : context.tr('voice.hold_to_record'),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRipple(double level, double size, double opacity) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted && _isRecording) {
          setState(() {});
        }
      },
      builder: (context, value, child) {
        return Container(
          width: size * (0.7 + (0.3 * value)),
          height: size * (0.7 + (0.3 * value)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.accentPink.withValues(
                alpha: opacity * (1.0 - value),
              ),
              width: 2,
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showPermissionRationale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mic, color: AppTheme.info),
            const SizedBox(width: AppTheme.spacing12),
            Text(context.tr('voice.permission_title')),
          ],
        ),
        content: Text(context.tr('voice.permission_rationale')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.allow')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.warning),
            const SizedBox(width: AppTheme.spacing12),
            Text(context.tr('voice.permission_denied_title')),
          ],
        ),
        content: Text(context.tr('voice.permission_denied_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.ok')),
          ),
        ],
      ),
    );
  }
}

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
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

/// Permission states for voice recording
enum VoicePermissionState {
  notDetermined, // Not yet requested
  granted,       // Permission granted
  denied,        // Permission denied
}

/// Home Screen with modern UI and voice input
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  double _soundLevel = 0.0;
  String _recognizedText = '';
  VoicePermissionState _permissionState = VoicePermissionState.notDetermined;
  late AnimationController _listeningTextController;
  late AnimationController _swipeTextController;
  late Animation<double> _listeningFadeAnimation;
  late Animation<double> _swipeSlideAnimation;
  late WidgetsBindingObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();

    // Check permission status on init
    _checkPermissionStatus();

    // Listen for app lifecycle changes to refresh permission status
    _lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('📱 [HomeScreen] App resumed, rechecking permissions...');
        _checkPermissionStatus();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    // Listening text fade animation
    _listeningTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _listeningFadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _listeningTextController,
        curve: Curves.easeInOut,
      ),
    );

    // Swipe text slide animation
    _swipeTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _swipeSlideAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _swipeTextController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _listeningTextController.dispose();
    _swipeTextController.dispose();
    _voiceService.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    debugPrint('🔐 [HomeScreen] Checking permission status...');
    debugPrint('🔐 [HomeScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}');

    final hasPermission = await _voiceService.hasPermission();
    debugPrint('🔐 [HomeScreen] hasPermission result: $hasPermission');

    if (hasPermission) {
      setState(() {
        _permissionState = VoicePermissionState.granted;
      });
      debugPrint('✅ [HomeScreen] Setting state to GRANTED');
    } else {
      // Check if permissions were permanently denied (user must go to settings)
      final micStatus = await Permission.microphone.status;
      debugPrint('🔐 [HomeScreen] Microphone status: ${micStatus.name} (isGranted: ${micStatus.isGranted}, isDenied: ${micStatus.isDenied}, isPermanentlyDenied: ${micStatus.isPermanentlyDenied})');

      bool isPermanentlyDenied = micStatus.isPermanentlyDenied;

      // On iOS, also check speech permission
      if (Platform.isIOS) {
        final speechStatus = await Permission.speech.status;
        debugPrint('🔐 [HomeScreen] Speech status: ${speechStatus.name} (isGranted: ${speechStatus.isGranted}, isDenied: ${speechStatus.isDenied}, isPermanentlyDenied: ${speechStatus.isPermanentlyDenied})');
        isPermanentlyDenied = isPermanentlyDenied || speechStatus.isPermanentlyDenied;
      }

      // Only treat as "denied" if permanently denied (user must open settings)
      // Otherwise treat as "not determined" (can request permission)
      // Note: On first launch, iOS returns isDenied:true but isPermanentlyDenied:false
      // which should be treated as "not determined" so user can tap to enable
      if (isPermanentlyDenied) {
        setState(() {
          _permissionState = VoicePermissionState.denied;
        });
        debugPrint('❌ [HomeScreen] Setting state to DENIED (permanently denied - requires settings)');
      } else {
        setState(() {
          _permissionState = VoicePermissionState.notDetermined;
        });
        debugPrint('❓ [HomeScreen] Setting state to NOT_DETERMINED (can request permission)');
      }
    }

    debugPrint('🔐 [HomeScreen] Final permission state: ${_permissionState.name}');
  }

  Future<void> _requestPermission() async {
    debugPrint('🔐 [HomeScreen] Requesting permission...');

    final shouldRequest = await _showPermissionRationale();
    if (!shouldRequest || !mounted) {
      debugPrint('❌ [HomeScreen] User declined permission rationale');
      return;
    }

    final granted = await _voiceService.requestPermission();
    debugPrint('🔐 [HomeScreen] Permission granted: $granted');

    if (granted) {
      setState(() {
        _permissionState = VoicePermissionState.granted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('voice.permission_granted')),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _permissionState = VoicePermissionState.denied;
      });
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [HomeScreen] Starting recording...');

    // Permission should already be granted at this point
    if (_permissionState != VoicePermissionState.granted) {
      debugPrint('❌ [HomeScreen] Cannot record - permission not granted');
      return;
    }

    if (!mounted) return;
    final configProvider = context.read<AppConfigProvider>();
    final language = configProvider.language;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    // Start animations
    _listeningTextController.repeat(reverse: true);
    _swipeTextController.repeat(reverse: true);

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
      // Stop animations if recording failed
      _listeningTextController.stop();
      _swipeTextController.stop();

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

    // Stop animations
    _listeningTextController.stop();
    _swipeTextController.stop();

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

    // Stop animations
    _listeningTextController.stop();
    _swipeTextController.stop();

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
                    expandedHeight: 120,
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
                                Text(
                                  context.tr('home.hello'),
                                  style: textTheme.headlineMedium?.copyWith(
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
                        AnimatedBuilder(
                          animation: _listeningFadeAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _listeningFadeAnimation.value,
                              child: Text(
                                context.tr('voice.listening'),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            );
                          },
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
                        AnimatedBuilder(
                          animation: _swipeSlideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _swipeSlideAnimation.value),
                              child: Opacity(
                                opacity: 0.7 + (_listeningFadeAnimation.value * 0.3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppTheme.spacing8),
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
                            );
                          },
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
    // Determine button appearance based on permission state
    final String buttonText;
    final IconData buttonIcon;
    final Gradient buttonGradient;
    final VoidCallback? onTapAction;
    final bool enableHold;

    if (_isRecording) {
      // Recording state
      buttonText = context.tr('home.recording');
      buttonIcon = Icons.mic;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = null;
      enableHold = true;
    } else {
      switch (_permissionState) {
        case VoicePermissionState.granted:
          // Permission granted - ready to record
          buttonText = context.tr('voice.hold_to_record');
          buttonIcon = Icons.mic_none;
          buttonGradient = AppTheme.primaryGradient;
          onTapAction = () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('voice.hold_instruction')),
                duration: const Duration(seconds: 2),
              ),
            );
          };
          enableHold = true;
          break;

        case VoicePermissionState.notDetermined:
          // Permission not requested yet
          buttonText = context.tr('voice.tap_to_enable');
          buttonIcon = Icons.mic_off;
          buttonGradient = AppTheme.primaryGradient;
          onTapAction = _requestPermission;
          enableHold = false;
          break;

        case VoicePermissionState.denied:
          // Permission denied
          buttonText = context.tr('voice.voice_disabled');
          buttonIcon = Icons.mic_off;
          buttonGradient = LinearGradient(
            colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.8)],
          );
          onTapAction = _showPermissionDeniedDialog;
          enableHold = false;
          break;
      }
    }

    return GestureDetector(
      onLongPressStart: enableHold && !_isRecording ? (_) => _startRecording() : null,
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
          gradient: buttonGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTapAction,
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
                    buttonIcon,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    buttonText,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
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
            Expanded(
              child: Text(context.tr('voice.permission_title')),
            ),
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
            Expanded(
              child: Text(context.tr('voice.permission_denied_title')),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('voice.permission_denied_message')),
            const SizedBox(height: AppTheme.spacing16),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadiusSmall,
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      context.tr('voice.permission_settings_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Recheck permission after returning from settings
              if (mounted) {
                await _checkPermissionStatus();
              }
            },
            icon: const Icon(Icons.settings),
            label: Text(context.tr('voice.open_settings')),
          ),
        ],
      ),
    );
  }
}

/// Observer for app lifecycle changes
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;

  _AppLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

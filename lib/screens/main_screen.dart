import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';
import '../services/preferences_service.dart';
import '../services/data_collection_service.dart';
import '../services/gemini_usage_limit_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_tutorial_overlay.dart';
import '../widgets/home/editable_expense_dialog.dart';
import 'home_screen.dart';
import 'report_screen.dart';

/// Main screen with bottom navigation bar and global voice input
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  // Voice service and state
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  bool _isSwiping = false; // Track if user is swiping to cancel
  double _soundLevel = 0.0;
  String _recognizedText = '';
  PermissionStatus? _micPermissionStatus;
  bool _voiceServiceInitFailed = false;
  late AnimationController _listeningTextController;
  late AnimationController _swipeTextController;
  late Animation<double> _listeningFadeAnimation;
  late Animation<double> _swipeSlideAnimation;
  late WidgetsBindingObserver _lifecycleObserver;

  // Tutorial state
  final PreferencesService _prefsService = PreferencesService();
  bool _showTutorial = false;
  bool _shouldShowPulse = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _screens = [const HomeScreen(), const ReportScreen()];

    // Check tutorial status first (show immediately on first launch)
    _checkTutorialStatus();

    // Check permission status on init
    _checkPermissionStatus();

    // Generate pending recurring expenses on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExpenseProvider>().generateRecurringExpenses();
        // Log initial screen view (Home tab)
        context.read<AnalyticsService>().logHomeScreen();
      }
    });

    // Listen for app lifecycle changes to refresh permission status
    _lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('📱 [MainScreen] App resumed, rechecking permissions...');
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
      CurvedAnimation(parent: _swipeTextController, curve: Curves.easeInOut),
    );

    // Pulse animation for tutorial hint
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _listeningTextController.dispose();
    _swipeTextController.dispose();
    _pulseController.dispose();
    _voiceService.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    debugPrint('🔐 [MainScreen] Checking permission status...');
    debugPrint(
      '🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    final micStatus = await Permission.microphone.status;
    debugPrint('🔐 [MainScreen] Microphone: ${micStatus.name}');

    setState(() {
      _micPermissionStatus = micStatus;
    });

    debugPrint('🔐 [MainScreen] Permission status updated');

    // If microphone is granted, try to initialize VoiceService
    // This will trigger iOS speech permission dialog if not yet granted
    if (micStatus.isGranted && !_voiceService.isInitialized) {
      debugPrint(
        '🎙️ [MainScreen] Microphone granted, initializing VoiceService...',
      );
      final initialized = await _voiceService.initialize();
      debugPrint('🎙️ [MainScreen] VoiceService initialized: $initialized');

      if (!initialized) {
        debugPrint('⚠️ [MainScreen] VoiceService initialization failed');
        setState(() {
          _voiceServiceInitFailed = true;
        });
      } else {
        setState(() {
          _voiceServiceInitFailed = false;
        });
      }
    }
  }

  Future<void> _checkTutorialStatus() async {
    debugPrint('📚 [MainScreen] Checking tutorial status...');
    final hasShown = await _prefsService.hasShownVoiceTutorial();

    debugPrint('📚 [MainScreen] Tutorial shown: $hasShown');

    if (!hasShown) {
      // Show tutorial immediately on first launch
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _showTutorial = true;
        });
      }
    } else {
      // Always show pulsing hint after tutorial is dismissed
      setState(() {
        _shouldShowPulse = true;
      });
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _dismissTutorial() async {
    debugPrint('📚 [MainScreen] Dismissing tutorial...');
    await _prefsService.markVoiceTutorialShown();

    setState(() {
      _showTutorial = false;
      _shouldShowPulse = true;
    });

    // Start pulsing animation for next few uses
    _pulseController.repeat(reverse: true);

    // Show data collection consent dialog after tutorial is dismissed
    if (mounted) {
      _checkAndShowConsentDialog();
    }
  }

  /// Check if user has been asked for data collection consent
  /// If not, show the consent dialog
  Future<void> _checkAndShowConsentDialog() async {
    if (!mounted) return;

    final dataCollectionService = context.read<DataCollectionService>();

    // Check if user has been asked before
    final hasBeenAsked = await dataCollectionService.hasBeenAskedForConsent();

    if (!hasBeenAsked) {
      // Wait a moment for tutorial dismissal animation to complete
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Show consent dialog
      _showConsentDialog(dataCollectionService);
    }
  }

  /// Show data collection consent dialog
  void _showConsentDialog(DataCollectionService dataCollectionService) {
    // Automatically enable data collection by default
    dataCollectionService.setConsent(true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.insights, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                context.tr('data_collection.consent_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('data_collection.consent_message'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.info,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        context.tr('data_collection.settings_note'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: Text(context.tr('data_collection.accept')),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryMint,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasRequiredPermissions() {
    if (_micPermissionStatus == null) return false;
    return _micPermissionStatus!.isGranted && _voiceService.isInitialized;
  }

  bool _shouldShowDisabled() {
    if (_micPermissionStatus == null) return false;
    return _micPermissionStatus!.isPermanentlyDenied || _voiceServiceInitFailed;
  }

  Future<void> _requestPermission() async {
    debugPrint('🔐 [MainScreen] Requesting permission...');
    debugPrint(
      '🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    final shouldRequest = await _showPermissionRationale();
    if (!shouldRequest || !mounted) {
      debugPrint('❌ [MainScreen] User declined permission rationale');
      return;
    }

    debugPrint(
      '🔐 [MainScreen] User accepted rationale, requesting microphone permission...',
    );

    final micStatus = await Permission.microphone.request();
    debugPrint('🔐 [MainScreen] Microphone result: ${micStatus.name}');

    if (mounted) {
      await _checkPermissionStatus();
    }
  }

  DateTime? _recordingStartTime;

  Future<void> _startRecording() async {
    debugPrint('🎤 [MainScreen] Starting recording...');

    final hasPermission = _hasRequiredPermissions();
    if (!hasPermission) {
      debugPrint('❌ [MainScreen] Cannot record - permissions not granted');
      return;
    }

    if (!mounted) return;
    final configProvider = context.read<AppConfigProvider>();
    final language = configProvider.language;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    // Track recording start time for analytics
    _recordingStartTime = DateTime.now();

    // Log voice input started
    context.read<AnalyticsService>().logVoiceInputStarted(language: language);

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

    if (success) {
      // Provide haptic feedback when recording starts successfully
      HapticFeedback.selectionClick();
    }

    if (!success && mounted) {
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
    debugPrint('🛑 [MainScreen] Stopping recording...');
    await _voiceService.stopListening();

    // Provide haptic feedback when stopping recording
    HapticFeedback.selectionClick();

    _listeningTextController.stop();
    _swipeTextController.stop();

    setState(() {
      _isRecording = false;
      _isSwiping = false;
    });

    // Calculate recording duration for analytics
    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;

    // Log voice input completion
    if (mounted) {
      final language = context.read<AppConfigProvider>().language;
      context.read<AnalyticsService>().logVoiceInputCompleted(
        success: _recognizedText.isNotEmpty,
        durationSeconds: duration,
        language: language,
      );
    }

    if (_recognizedText.isNotEmpty) {
      _processExpense(_recognizedText);
    }
  }

  Future<void> _cancelRecording() async {
    debugPrint('❌ [MainScreen] Canceling recording...');
    await _voiceService.cancelListening();

    _listeningTextController.stop();
    _swipeTextController.stop();

    setState(() {
      _isRecording = false;
      _isSwiping = false;
      _recognizedText = '';
    });

    // Log voice input cancelled
    if (mounted) {
      final language = context.read<AppConfigProvider>().language;
      context.read<AnalyticsService>().logVoiceInputCancelled(
        language: language,
      );
    }
  }

  Future<void> _processExpense(String input) async {
    debugPrint('💰 [MainScreen] Processing expense: "$input"');

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
      final categoryProvider = context.read<CategoryProvider>();
      final usageLimitService = context.read<GeminiUsageLimitService>();
      final analyticsService = context.read<AnalyticsService>();
      final results = await ExpenseParser.parse(
        input,
        expenseProvider.currentUserId,
        categoryProvider.categories,
        usageLimitService: usageLimitService,
        analyticsService: analyticsService,
      );
      if (mounted) Navigator.pop(context);

      // Check if Gemini limit was reached
      if (results.isNotEmpty &&
          results.first.errorMessage == 'GEMINI_LIMIT_REACHED') {
        if (mounted) {
          final limit = usageLimitService.dailyLimit;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'voice.gemini_limit_reached',
                  namedArgs: {'limit': limit.toString()},
                ),
              ),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

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
      debugPrint('❌ [MainScreen] Error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('common.error', namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExpenseResultsDialog(List<ParseResult> results) {
    showDialog(
      context: context,
      builder: (context) => EditableExpenseDialog(results: results),
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
              child: Text(
                Platform.isIOS
                    ? context.tr('voice.permission_title_ios')
                    : context.tr('voice.permission_title_android'),
              ),
            ),
          ],
        ),
        content: Text(
          Platform.isIOS
              ? context.tr('voice.permission_rationale_ios')
              : context.tr('voice.permission_rationale_android'),
        ),
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
            Expanded(child: Text(context.tr('voice.permission_denied_title'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Platform.isIOS
                  ? context.tr('voice.permission_denied_message_ios')
                  : context.tr('voice.permission_denied_message_android'),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadiusSmall,
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.info,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      Platform.isIOS
                          ? context.tr('voice.permission_settings_hint_ios')
                          : context.tr(
                              'voice.permission_settings_hint_android',
                            ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.info),
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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Log screen view based on tab
    final analyticsService = context.read<AnalyticsService>();
    if (index == 0) {
      analyticsService.logHomeScreen();
    } else if (index == 1) {
      analyticsService.logReportScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usageLimitService = context.watch<GeminiUsageLimitService>();

    return Stack(
      children: [
        // Main Scaffold with content and bottom navigation
        Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false, // Let bottom nav handle its own safe area
            child: Column(
              children: [
                // Gemini usage limit banner
                FutureBuilder<int>(
                  future: usageLimitService.getRemainingCount(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final remaining = snapshot.data!;
                    final limit = usageLimitService.dailyLimit;

                    // Don't show banner if plenty remaining
                    if (remaining > AppConstants.geminiWarningThreshold) {
                      return const SizedBox.shrink();
                    }

                    // Determine color and icon based on remaining count
                    Color bannerColor;
                    IconData bannerIcon;
                    if (remaining == 0) {
                      bannerColor = AppTheme.error;
                      bannerIcon = Icons.block;
                    } else if (remaining <=
                        AppConstants.geminiCriticalThreshold) {
                      bannerColor = AppTheme.warning;
                      bannerIcon = Icons.warning_amber;
                    } else {
                      bannerColor = AppTheme.info;
                      bannerIcon = Icons.info_outline;
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing12,
                      ),
                      decoration: BoxDecoration(
                        color: bannerColor.withValues(alpha: 0.15),
                        border: Border(
                          bottom: BorderSide(
                            color: bannerColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(bannerIcon, color: bannerColor, size: 20),
                          const SizedBox(width: AppTheme.spacing8),
                          Expanded(
                            child: Text(
                              remaining == 0
                                  ? context.tr(
                                      'voice.gemini_limit_reached',
                                      namedArgs: {'limit': limit.toString()},
                                    )
                                  : context.tr(
                                      'voice.gemini_limit_warning',
                                      namedArgs: {
                                        'remaining': remaining.toString(),
                                        'limit': limit.toString(),
                                      },
                                    ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: bannerColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Main content
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: _screens),
                ),
              ],
            ),
          ), // SafeArea
          // Notched BottomAppBar with navigation items
          bottomNavigationBar: BottomAppBar(
            color: Colors.transparent,
            elevation: 0,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LiquidGlassLayer(
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: IconButton(
                      icon: Icon(
                        _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                      ),
                      color: _currentIndex == 0
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: () => _onTabTapped(0),
                      tooltip: context.tr('navigation.home'),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Space for the FAB
                LiquidGlassLayer(
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: IconButton(
                      icon: Icon(
                        _currentIndex == 1
                            ? Icons.calendar_month
                            : Icons.calendar_month_outlined,
                      ),
                      color: _currentIndex == 1
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: () => _onTabTapped(1),
                      tooltip: context.tr('navigation.transactions'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Voice FAB docked in the center
          floatingActionButton: _buildVoiceFAB(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.miniCenterDocked,
        ),

        // Full-screen recording overlay (covers everything including bottom nav and FAB)
        if (_isRecording)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerUp: (_) {
                debugPrint(
                  '👆 [MainScreen] Pointer UP detected, _isSwiping: $_isSwiping',
                );
                // Only stop recording if user didn't swipe to cancel
                if (!_isSwiping) {
                  _stopRecording();
                }
                // Reset swipe flag
                setState(() {
                  _isSwiping = false;
                });
              },
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta! < -10) {
                    debugPrint('👆 [MainScreen] Swipe up detected - canceling');
                    setState(() {
                      _isSwiping = true;
                    });
                    _cancelRecording();
                  }
                },
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
                          padding: const EdgeInsets.all(AppTheme.spacing20),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.95),
                            borderRadius: AppTheme.borderRadiusMedium,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _recognizedText,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spacing32),
                      // Tap to stop instruction
                      AnimatedBuilder(
                        animation: _listeningFadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity:
                                0.7 + (_listeningFadeAnimation.value * 0.3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Text(
                                  context.tr('voice.tap_to_stop'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      // Swipe to cancel instruction
                      AnimatedBuilder(
                        animation: _swipeSlideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _swipeSlideAnimation.value),
                            child: Opacity(
                              opacity:
                                  0.7 + (_listeningFadeAnimation.value * 0.3),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
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
            ),
          ),

        // Tutorial overlay
        if (_showTutorial)
          VoiceTutorialOverlay(
            onDismiss: _dismissTutorial,
            fabPosition: _getFABPosition(),
          ),
      ],
    );
  }

  Offset _getFABPosition() {
    // Get actual FAB position from its RenderBox
    try {
      final RenderBox? renderBox =
          _fabKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        // Return the center of the FAB
        return Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [MainScreen] Could not get FAB position: $e');
    }

    // Fallback to approximation if RenderBox not available yet
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height - 80);
  }

  Widget _buildVoiceFAB() {
    final IconData buttonIcon;
    final Gradient buttonGradient;
    final VoidCallback? onTapAction;

    if (_isRecording) {
      // Recording: tap to stop
      buttonIcon = Icons.mic;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = () {
        debugPrint('👆 [MainScreen] Tap to stop recording');
        _stopRecording();
      };
    } else if (_hasRequiredPermissions()) {
      // Ready: tap to start recording
      buttonIcon = Icons.mic_none;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = () {
        debugPrint('👆 [MainScreen] Tap to start recording');
        _startRecording();
      };
    } else if (_shouldShowDisabled()) {
      // Permission denied: tap to show dialog
      buttonIcon = Icons.mic_off;
      buttonGradient = LinearGradient(
        colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.8)],
      );
      onTapAction = _showPermissionDeniedDialog;
    } else {
      // No permission yet: tap to request
      buttonIcon = Icons.mic_off;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = _requestPermission;
    }

    final fabWidget = LiquidGlassLayer(
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 60),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: buttonGradient.withOpacity(0.5),
            shape: BoxShape.circle,
            boxShadow: AppTheme.shadowLarge,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTapAction,
              customBorder: const CircleBorder(),
              child: Icon(buttonIcon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );

    // Wrap with pulsing rings if needed
    final Widget result;
    if (_shouldShowPulse && !_isRecording) {
      result = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: 72 * _pulseAnimation.value * 1.2,
                height: 72 * _pulseAnimation.value * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentPink.withValues(
                      alpha: 0.3 * (2 - _pulseAnimation.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // Inner ring
              Container(
                width: 72 * _pulseAnimation.value,
                height: 72 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentOrange.withValues(
                      alpha: 0.4 * (2 - _pulseAnimation.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // FAB
              child!,
            ],
          );
        },
        child: fabWidget,
      );
    } else {
      result = fabWidget;
    }

    // Wrap entire FAB with key for position tracking
    return Container(key: _fabKey, child: result);
  }

  Widget _buildRipple(double level, double size, double opacity) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
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

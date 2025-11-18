import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firebase_options.dart';
import 'providers/app_config_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/category_provider.dart';
import 'providers/report_provider.dart';
import 'providers/recurring_template_provider.dart';
import 'services/preferences_service.dart';
import 'services/database_manager.dart';
import 'services/expense_service.dart';
import 'services/recurring_template_service.dart';
import 'services/recurring_expense_service.dart';
import 'services/gemini_expense_parser.dart';
import 'services/data_collection_service.dart';
import 'services/gemini_usage_limit_service.dart';
import 'services/analytics_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ [Main] Firebase initialized');

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

  // Initialize services
  final preferencesService = PreferencesService();
  await preferencesService.init();

  // Get current language for database migration
  final config = await preferencesService.getConfig();
  final currentLanguage = config.language;

  // Initialize database manager (centralized database) with language for migration
  final databaseManager = DatabaseManager();
  await databaseManager.init(language: currentLanguage);

  // Initialize services with shared database
  final expenseService = ExpenseService(databaseManager);
  await expenseService.init();

  final recurringTemplateService = RecurringTemplateService(databaseManager);
  await recurringTemplateService.init();

  final recurringExpenseService = RecurringExpenseService(
    expenseService,
    recurringTemplateService,
  );

  // Initialize Gemini parser
  GeminiExpenseParser.initialize();

  // Initialize data collection service
  final dataCollectionService = DataCollectionService();
  await dataCollectionService.init();

  // Initialize Gemini usage limit service
  final geminiUsageLimitService = GeminiUsageLimitService();
  await geminiUsageLimitService.init();

  // Initialize Analytics service
  final analyticsService = AnalyticsService();
  await analyticsService.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('vi', 'VN'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
        Locale('th', 'TH'),
        Locale('es', 'ES'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MyApp(
        preferencesService: preferencesService,
        expenseService: expenseService,
        recurringTemplateService: recurringTemplateService,
        recurringExpenseService: recurringExpenseService,
        dataCollectionService: dataCollectionService,
        geminiUsageLimitService: geminiUsageLimitService,
        analyticsService: analyticsService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PreferencesService preferencesService;
  final ExpenseService expenseService;
  final RecurringTemplateService recurringTemplateService;
  final RecurringExpenseService recurringExpenseService;
  final DataCollectionService dataCollectionService;
  final GeminiUsageLimitService geminiUsageLimitService;
  final AnalyticsService analyticsService;

  const MyApp({
    super.key,
    required this.preferencesService,
    required this.expenseService,
    required this.recurringTemplateService,
    required this.recurringExpenseService,
    required this.dataCollectionService,
    required this.geminiUsageLimitService,
    required this.analyticsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DataCollectionService>.value(value: dataCollectionService),
        Provider<ExpenseService>.value(value: expenseService),
        Provider<GeminiUsageLimitService>.value(value: geminiUsageLimitService),
        Provider<AnalyticsService>.value(value: analyticsService),
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(
            preferencesService,
            analyticsService: analyticsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ExpenseProvider(
            expenseService,
            recurringExpenseService: recurringExpenseService,
            analyticsService: analyticsService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => CategoryProvider(expenseService)),
        ChangeNotifierProvider(
          create: (_) => RecurringTemplateProvider(recurringTemplateService),
        ),
        ChangeNotifierProxyProvider3<ExpenseProvider, CategoryProvider,
            AppConfigProvider, ReportProvider>(
          create: (context) => ReportProvider(
            Provider.of<ExpenseProvider>(context, listen: false),
            Provider.of<CategoryProvider>(context, listen: false),
            Provider.of<AppConfigProvider>(context, listen: false),
          ),
          update: (context, expenseProvider, categoryProvider, appConfigProvider,
                  previous) =>
              previous ??
              ReportProvider(
                expenseProvider,
                categoryProvider,
                appConfigProvider,
              ),
        ),
      ],
      child: Consumer<AppConfigProvider>(
        builder: (context, configProvider, _) {
          // Show loading screen while config is being loaded
          if (configProvider.isLoading) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryMint),
                ),
              ),
            );
          }

          // Convert theme mode string to ThemeMode enum
          ThemeMode themeMode;
          switch (configProvider.themeMode) {
            case 'light':
              themeMode = ThemeMode.light;
              break;
            case 'dark':
              themeMode = ThemeMode.dark;
              break;
            case 'system':
            default:
              themeMode = ThemeMode.system;
              break;
          }

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            // Show onboarding if not completed, otherwise show main screen
            home: configProvider.isOnboardingComplete
                ? const MainScreen()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

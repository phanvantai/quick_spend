import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firebase_options.dart';
import 'providers/app_config_provider.dart';
import 'providers/expense_provider.dart';
import 'services/preferences_service.dart';
import 'services/expense_service.dart';
import 'services/gemini_expense_parser.dart';
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

  final expenseService = ExpenseService();
  await expenseService.init();

  // Initialize Gemini parser
  GeminiExpenseParser.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('vi', 'VN')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MyApp(
        preferencesService: preferencesService,
        expenseService: expenseService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PreferencesService preferencesService;
  final ExpenseService expenseService;

  const MyApp({
    super.key,
    required this.preferencesService,
    required this.expenseService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(preferencesService),
        ),
        ChangeNotifierProvider(create: (_) => ExpenseProvider(expenseService)),
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

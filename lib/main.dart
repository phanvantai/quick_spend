import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firebase_options.dart';
import 'providers/app_config_provider.dart';
import 'services/preferences_service.dart';
import 'services/gemini_expense_parser.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ [Main] Firebase initialized');

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

  // Initialize preferences service
  final preferencesService = PreferencesService();
  await preferencesService.init();

  // Initialize Gemini parser
  GeminiExpenseParser.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MyApp(preferencesService: preferencesService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final PreferencesService preferencesService;

  const MyApp({super.key, required this.preferencesService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppConfigProvider(preferencesService),
        ),
      ],
      child: Consumer<AppConfigProvider>(
        builder: (context, configProvider, _) {
          // Show loading screen while config is being loaded
          if (configProvider.isLoading) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            );
          }

          // Set locale based on user preference
          final locale = Locale(configProvider.language);
          if (context.locale != locale) {
            context.setLocale(locale);
          }

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Quick Spend',
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                ThemeMode.light, // TODO: Add dark mode toggle in settings
            // Show onboarding if not completed, otherwise show home
            home: configProvider.isOnboardingComplete
                ? const HomeScreen()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

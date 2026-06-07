import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/config/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/home/screens/profile_detail_screen.dart';
import 'features/home/screens/nutrition_scan_preview_screen.dart';
import 'features/home/screens/nutrition_scan_result_screen.dart';
import 'features/main/screens/main_screen.dart';
import 'features/splash/screens/animated_splash_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/security_lock_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsProvider, (int, String)>(
      selector: (context, provider) => (provider.themeColorHex, provider.languageCode),
      builder: (context, data, child) {
        final settings = context.read<SettingsProvider>();
        final themeColorHex = data.$1;
        return MaterialApp(
          title: 'SHCare',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: settings.locale,
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
            Locale('ja', 'JP'),
            Locale('ko', 'KR'),
            Locale('zh', 'CN'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Điểm bắt đầu là AnimatedSplashScreen — hiệu ứng intro premium
          // thay thế RootScreen tĩnh, vừa chạy animation vừa load data ngầm
          initialRoute: '/',
          routes: {
            '/': (context) => const AnimatedSplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/main': (context) => MainScreen(key: ValueKey(themeColorHex)),
            '/profile': (context) => ProfileDetailScreen(key: ValueKey(themeColorHex)),
            '/nutrition_preview': (context) => const NutritionScanPreviewScreen(),
            '/nutrition_result': (context) => const NutritionScanResultScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/security-lock': (context) => SecurityLockScreen(
                  onUnlockSuccess: () {
                    Navigator.pushReplacementNamed(context, '/main');
                  },
                ),
          },
        );
      },
    );
  }
}


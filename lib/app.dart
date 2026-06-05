import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/main/screens/main_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Đặt route mặc định vào Login
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

// Widget RootPlaceholder có thể giữ lại làm Splash Screen hoặc màn hình chờ
class RootPlaceholder extends StatelessWidget {
  const RootPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // Logic điều hướng sau khi khởi tạo có thể thêm ở đây
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SHCare App', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 10),
            const Text('Hệ thống đang khởi tạo...'),
          ],
        ),
      ),
    );
  }
}

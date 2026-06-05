import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/home/screens/profile_detail_screen.dart';
import 'features/main/screens/main_screen.dart';
import 'providers/auth_provider.dart';

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

      // Điểm bắt đầu là RootScreen để kiểm tra bất đồng bộ trạng thái đăng nhập và Onboarding
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/main': (context) => const MainScreen(),
        '/profile': (context) => const ProfileDetailScreen(),
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndOnboarding();
    });
  }

  Future<void> _checkAuthAndOnboarding() async {
    final auth = context.read<AuthProvider>();
    
    // Nếu người dùng đã đăng nhập Firebase Auth
    if (FirebaseAuth.instance.currentUser != null) {
      // Đợi load UserModel từ Firestore
      await auth.loadCurrentUserModel();
      
      if (mounted) {
        // Kiểm tra xem đã hoàn thành onboarding chưa (chưa có chiều cao/cân nặng)
        if (auth.currentUser?.heightCm == null || auth.currentUser?.weightKg == null) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        } else {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } else {
      // Nếu chưa đăng nhập, đưa về Login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF0FA87E),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Đang chuẩn bị không gian sức khỏe...',
              style: TextStyle(
                color: Color(0xFF5A7068),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

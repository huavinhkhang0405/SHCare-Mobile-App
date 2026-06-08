import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shcare_app/providers/settings_provider.dart';
import 'package:shcare_app/features/settings/screens/settings_screen.dart';
import 'package:shcare_app/core/config/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsScreen renders correctly and shows options', (WidgetTester tester) async {
    final settingsProvider = SettingsProvider();
    await settingsProvider.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: MaterialApp(
          locale: settingsProvider.locale,
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
          home: const SettingsScreen(),
        ),
      ),
    );

    // Wait for assets loading and pump layouts
    await tester.pumpAndSettle();

    // Verify Settings Title is displayed (default is system settings in Vietnamese)
    expect(find.text('Cài đặt hệ thống'), findsOneWidget);

    // Verify sections are displayed
    expect(find.text('MÀU SẮC CHỦ ĐẠO'), findsOneWidget);
    expect(find.text('NGÔN NGỮ HIỂN THỊ'), findsOneWidget);
    expect(find.text('THÔNG BÁO ĐẨY'), findsOneWidget);
    expect(find.text('KHÓA ỨNG DỤNG'), findsOneWidget);
    expect(find.text('BỘ NHỚ TẠM'), findsOneWidget);

    // Verify default cache display
    expect(find.text('0.00 MB'), findsOneWidget);
  });
}

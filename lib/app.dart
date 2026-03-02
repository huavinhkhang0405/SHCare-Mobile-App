import 'package:flutter/material.dart';

/* =========================================================
   FILE: app.dart

   Vai trò:
   - Root UI của toàn bộ ứng dụng
   - Cấu hình Theme
   - Cấu hình Navigation / Route
   - Xác định màn hình khởi đầu của app

   ⚠️ Quy tắc chỉnh sửa:

   UI/UX Team:
   - Được chỉnh theme
   - Được chỉnh routing
   - Được thay đổi màn hình Home

   Logic / Backend / AI Team:
   - Không chỉnh sửa file này
   ========================================================= */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      /* =========================================================
         APP CONFIGURATION
         =========================================================
         Thông tin chung của ứng dụng
      */

      title: 'SHCare',
      debugShowCheckedModeBanner: false,


      /* =========================================================
         THEME ZONE
         =========================================================
         UI Team chỉnh sửa theme tại đây
         Ví dụ:
         - màu chủ đạo
         - font
         - style button
         - style input
      */

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),


      /* =========================================================
         ROUTE ZONE
         =========================================================
         UI Team khai báo các màn hình ở đây

         Ví dụ:

         routes: {
           '/login': (context) => LoginScreen(),
           '/home': (context) => HomeScreen(),
           '/chat': (context) => ChatScreen(),
         },

      */


      /* =========================================================
         HOME SCREEN
         =========================================================
         Đây là màn hình đầu tiên của app.

         UI Team sẽ thay thế widget này bằng màn hình thật.

         Ví dụ:

         home: LoginScreen()
         home: HomeScreen()

      */

      home: const Scaffold(
        body: Center(
          child: Text(
            'SHCare App',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

    );
  }
}
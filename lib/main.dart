import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/firebase_options.dart';
import 'app.dart';
import 'core/providers/audio_provider.dart';
import 'features/home/providers/health_provider.dart';
import 'providers/auth_provider.dart';
import 'services/screen_time_service.dart';
import 'services/notification_service.dart';

/* =========================================================
   FILE: main.dart

   Vai trò:
   - Điểm khởi động của ứng dụng Flutter
   - Khởi tạo các dịch vụ hệ thống (Firebase, Environment)
   - Khai báo Provider để toàn bộ ứng dụng có thể sử dụng

   ⚠️ Lưu ý cho các thành viên:
   - Không thêm UI vào file này
   - Không chỉnh sửa logic khởi tạo Firebase
   - Chỉ nhóm Logic/State được phép thêm Provider
   ========================================================= */

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Đọc dữ liệu mới nhất từ ổ cứng

      final currentUser = prefs.getString('current_user_email') ?? '';
      final hasShownKey = '${currentUser}_has_shown_screentime_alert';
      final hasShownAlert = prefs.getBool(hasShownKey) ?? false;

      if (!hasShownAlert) {
        final screenTimeService = ScreenTimeService();
        final minutes = await screenTimeService.getTotalSocialMediaUsageMinutes();
        
        // Ngưỡng 5 phút để test cảnh báo ngầm hoạt động
        if (minutes >= 5) {
          final usageDetails = await screenTimeService.getSocialMediaUsageToday();
          
          await NotificationService.init();
          await NotificationService.showNotification(
            title: '⚠️ CẢNH BÁO SỨC KHỎE SỐ',
            body: 'Bạn đã dùng Mạng xã hội/Game quá 5 phút hôm nay! ($usageDetails)',
          );

          await prefs.setBool(hasShownKey, true);
        }
      }
    } catch (e) {
      debugPrint('🚨 [WorkManager] Lỗi thực thi tác vụ chạy ngầm: $e');
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  /* =========================================================
     STEP 1: Khởi tạo Flutter Engine
     =========================================================
     Bắt buộc trước khi sử dụng async code trong main()
     hoặc trước khi khởi tạo Firebase
  */
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Workmanager cho dịch vụ chạy nền
  try {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  } catch (e) {
    debugPrint('🚨 [WorkManager] Không thể khởi tạo: $e');
  }

  /* =========================================================
     STEP 2: Load biến môi trường (.env)
     =========================================================
     Nơi chứa các thông tin nhạy cảm như:

     - Gemini API Key
     - Firebase config
     - API endpoint

     Nhóm AI hoặc Backend có thể thêm key vào file .env
  */
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // In ra console dòng chữ đỏ để đập vào mắt developer
    debugPrint('🚨 [LỖI NGHIÊM TRỌNG]: Không tìm thấy file .env!');
    debugPrint(
      '👉 Vui lòng copy file env.example, đổi tên thành .env và điền API Key trước khi chạy app.',
    );
    throw Exception('Missing .env file');
  }

  /* =========================================================
     STEP 3: Khởi tạo Firebase
     =========================================================
     Kết nối ứng dụng Flutter với Firebase project.

     Các chức năng có thể sử dụng sau bước này:
     - Firestore Database
     - Authentication
     - Cloud Functions
     - Storage

     ⚠️ Không chỉnh sửa nếu không cần thiết
  */
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /* =========================================================
     STEP 4: Chạy ứng dụng Flutter
     =========================================================
     MultiProvider giúp chia sẻ state cho toàn bộ ứng dụng
  */

  runApp(
    MultiProvider(
      providers: [
        /* =================================================
           PROVIDER ZONE
           =================================================

           Đây là nơi khai báo các STATE của ứng dụng.

           Chỉ nhóm LOGIC / STATE chỉnh sửa khu vực này.

           Ví dụ các provider trong dự án:

           AuthProvider
           → quản lý đăng nhập Firebase

           ChatProvider
           → quản lý dữ liệu chat AI Gemini

           HealthProvider
           → quản lý dữ liệu sức khỏe người dùng

           Ví dụ thêm provider:
           ChangeNotifierProvider(
             create: (_) => AuthProvider(),
           ),
        */

        // Ví dụ:
        // ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProxyProvider<AuthProvider, HealthProvider>(
          create: (_) => HealthProvider(),
          update: (_, auth, health) {
            if (health != null) {
              health.updateUser(auth.currentUser);
            }
            return health!;
          },
        ),

        // Provider tạm để tránh lỗi khi chưa có Provider nào
        Provider.value(value: ''),
      ],

      // Root của ứng dụng (được định nghĩa trong app.dart)
      child: const MyApp(),
    ),
  );
}

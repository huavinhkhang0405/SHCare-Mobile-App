import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_options.dart';
import 'app.dart';

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

Future<void> main() async {

  /* =========================================================
     STEP 1: Khởi tạo Flutter Engine
     =========================================================
     Bắt buộc trước khi sử dụng async code trong main()
     hoặc trước khi khởi tạo Firebase
  */
  WidgetsFlutterBinding.ensureInitialized();


  /* =========================================================
     STEP 2: Load biến môi trường (.env)
     =========================================================
     Nơi chứa các thông tin nhạy cảm như:

     - Gemini API Key
     - Firebase config
     - API endpoint

     Nhóm AI hoặc Backend có thể thêm key vào file .env
  */
  await dotenv.load(fileName: ".env");


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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


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
        // ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ChangeNotifierProvider(create: (_) => ChatProvider()),

        // Provider tạm để tránh lỗi khi chưa có Provider nào
        Provider.value(value: ''),
      ],

      // Root của ứng dụng (được định nghĩa trong app.dart)
      child: const MyApp(),
    ),
  );
}
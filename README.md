# Dự án Flutter SHCare

## 1. Cấu trúc dự án

    lib
    │
    ├── core
    │   └── config
    │       └── firebase_options.dart
    │
    ├── models
    │
    ├── providers
    │
    ├── screens
    │
    ├── services
    │
    ├── utils
    │
    ├── app.dart
    └── main.dart

### Vai trò các thư mục

  Thư mục                Mục đích
  ---------------------- ----------------------------------------------
  `screens/`             Các màn hình giao diện của ứng dụng
  `services/`            Gọi API, xử lý Firebase, tích hợp AI
  `providers/`           Quản lý trạng thái
  `models/`              Cấu trúc dữ liệu ứng dụng
  `utils/`               Hàm tiện ích
  `core/`                Cấu hình hệ thống
  `main.dart`            Điểm khởi chạy ứng dụng
  `app.dart`             Cấu hình giao diện chính

------------------------------------------------------------------------

# 2. Phân chia nhiệm vụ

## 1️⃣ UI / UX

**Trách nhiệm**

-   Xây dựng các màn hình UI
-   Thiết kế bố cục giao diện
-   Xây dựng component UI
-   Tối ưu trải nghiệm người dùng

**Thư mục thao tác**

    lib/screens/
    lib/utils/

**File được phép chỉnh sửa**

    app.dart
    screens/*

**File không chỉnh sửa**

    main.dart
    providers/
    services/

------------------------------------------------------------------------

## 2️⃣ Backend / Firebase

**Trách nhiệm**

-   Đọc/ghi dữ liệu Firestore
-   Xử lý xác thực người dùng
-   Xử lý dữ liệu phía backend

**Thư mục thao tác**

    lib/services/
    lib/models/

Ví dụ file:

    services/firestore_service.dart
    services/auth_service.dart
    models/user_model.dart

------------------------------------------------------------------------

## 3️⃣ AI Gemini

**Trách nhiệm**

-   Tích hợp Gemini API
-   Xử lý prompt
-   Xây dựng logic chat AI

**Thư mục thao tác**

    lib/services/

Ví dụ:

    services/gemini_service.dart

API key lưu trong:

    .env

------------------------------------------------------------------------

## 4️⃣ Logic / State

**Trách nhiệm**

-   Quản lý trạng thái ứng dụng
-   Kết nối UI với backend
-   Điều phối luồng dữ liệu trong ứng dụng

**Thư mục thao tác**

    lib/providers/

Ví dụ:

    providers/auth_provider.dart
    providers/chat_provider.dart

Nhiệm vụ này cũng sẽ khai báo provider trong `main.dart`.

------------------------------------------------------------------------

# 3. File quan trọng

## main.dart

Trách nhiệm:

-   Khởi tạo Firebase
-   Nạp biến môi trường
-   Đăng ký provider
-   Khởi chạy ứng dụng

⚠️ Chỉ nhiệm vụ **Logic / State** nên chỉnh sửa file này.

------------------------------------------------------------------------

## app.dart

Trách nhiệm:

-   Cấu hình `MaterialApp`
-   Quản lý theme
-   Quản lý điều hướng / routes
-   Định nghĩa màn hình khởi đầu

⚠️ Chỉ nhiệm vụ **UI / UX** nên chỉnh sửa file này.

------------------------------------------------------------------------

# 4. Quy trình Git

## Tạo nhánh tính năng

Ví dụ:

    feature/ui-home
    feature/firebase-booking
    feature/gemini-chat
    feature/provider-auth

------------------------------------------------------------------------

## Quy tắc commit

Mỗi nhánh chỉ nên tập trung vào **một tính năng**.

Ví dụ:

    feat: add home screen UI
    feat: implement firestore booking service
    feat: integrate gemini chat API
    feat: add auth provider

------------------------------------------------------------------------

## Pull Request

Pull request cần mô tả:

-   Những thay đổi đã thực hiện
-   Các thư mục bị ảnh hưởng
-   Hướng dẫn kiểm thử

Ví dụ:

    Changes:
    - Added HomeScreen
    - Updated routing in app.dart

    Affected folders:
    screens/
    app.dart

------------------------------------------------------------------------

# 5. Quy tắc phối hợp

-   Tránh chỉnh sửa cùng một file trong `services/`
-   Tách file theo domain chức năng

Ví dụ:

    firestore_service.dart
    gemini_service.dart
    auth_service.dart

Nếu `models/` thay đổi:

➡ Cập nhật `providers/` trong cùng pull request.

------------------------------------------------------------------------

Trước khi merge, kiểm tra các luồng chính:

    login
    read/write database
    AI chat

------------------------------------------------------------------------

# 6. Quy chuẩn code

-   Cố gắng giữ mỗi file dưới ~300 dòng khi có thể
-   Một class chỉ nên có một trách nhiệm
-   Business logic đặt ở `provider` hoặc `service`, không đặt trong UI

## 6.1. Tên File và Thư mục (Files & Directories)

Quy tắc: Sử dụng **snake_case** (chữ thường, cách nhau bằng dấu gạch dưới).

Đúng: `home_screen.dart`, `user_model.dart`, `auth_provider.dart`.

Sai: `HomeScreen.dart`, `userModel.dart`, `home-screen.dart`.

## 6.2. Tên Class, Enum, Extension

Quy tắc: Sử dụng **UpperCamelCase** (viết hoa chữ cái đầu tiên của mỗi từ, còn gọi là PascalCase).

Đúng: `class HomeScreen`, `class GeminiService`, `enum HealthStatus`.

Sai: `class homeScreen`, `class gemini_service`.

## 6.3. Tên Biến (Variables) và Hàm (Functions/Methods)

Quy tắc: Sử dụng **lowerCamelCase** (chữ cái đầu tiên viết thường, các chữ cái đầu của từ tiếp theo viết hoa).

Đúng: `String userName`, `int heartRate`, `void fetchUserData()`.

Sai: `String UserName`, `int heart_rate`, `void Fetch_User_Data()`.

## 6.4. Tên Hằng số (Constants)

Quy tắc:

-   Trong Dart, hằng số được khuyên dùng **lowerCamelCase** (giống tên biến).
-   Với biến môi trường (trong file `.env`), dùng **SCREAMING_SNAKE_CASE**.

Đúng (Dart): `const int maxRetries = 3;`, `const double defaultPadding = 16.0;`.

Đúng (`.env`): `GEMINI_API_KEY`, `FIREBASE_PROJECT_ID`.

## 6.5. Quy ước hậu tố (Suffixes) bắt buộc cho dự án

Để dễ tìm file trong VS Code (Ctrl + P), tên class và tên file phải có hậu tố thể hiện rõ vai trò:

-   **Giao diện:** kết thúc bằng `...Screen` hoặc `...Widget` (ví dụ: `LoginScreen`, `CustomButtonWidget`).
-   **Quản lý trạng thái:** kết thúc bằng `...Provider` (ví dụ: `AuthProvider`).
-   **Xử lý logic/API:** kết thúc bằng `...Service` (ví dụ: `GeminiService`, `FirebaseService`).
-   **Cấu trúc dữ liệu:** kết thúc bằng `...Model` (ví dụ: `UserModel`, `HealthRecordModel`).

------------------------------------------------------------------------

# 7. Tổng quan kiến trúc

Dự án áp dụng **kiến trúc phân lớp**:

    UI Layer
      ↓
    Provider (State Management)
      ↓
    Service Layer
      ↓
    Firebase / Gemini API

### Ví dụ luồng xử lý

    UI (screens)
       ↓
    Provider
       ↓
    Service
       ↓
    Firebase / AI API

Cấu trúc này giúp:

-   Tách biệt UI với business logic
-   Dễ bảo trì và mở rộng
-   Giảm xung đột khi merge code

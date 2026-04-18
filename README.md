# Dự án Flutter SHCare

## 1. Cấu trúc dự án

```text
lib
├── core
│   ├── config
│   │   └── firebase_options.dart
│   ├── constants
│   │   └── app_strings.dart
│   └── theme
│       └── app_colors.dart
├── models
│   └── user_model.dart
├── providers
│   └── auth_provider.dart
├── repositories
├── screens
│   └── login_screen.dart
├── services
│   ├── ai
│   │   └── gemini_service.dart
│   └── firebase
│       └── firestore_service.dart
├── utils
│   └── date_formatter.dart
├── app.dart
└── main.dart
```

### Vai trò các thư mục

| Thư mục | Mục đích |
| --- | --- |
| `core/config/` | Cấu hình hệ thống (Firebase options, cấu hình nền tảng) |
| `core/constants/` | Khai báo hằng số dùng chung toàn ứng dụng |
| `core/theme/` | Định nghĩa màu sắc, theme và style dùng lại |
| `models/` | Cấu trúc dữ liệu ứng dụng (Model) |
| `providers/` | Quản lý trạng thái và điều phối dữ liệu cho UI |
| `repositories/` | Lớp trung gian truy xuất dữ liệu giữa provider và service |
| `screens/` | Các màn hình giao diện của ứng dụng |
| `services/ai/` | Tích hợp AI/Gemini và xử lý prompt |
| `services/firebase/` | Tương tác Firebase/Firestore |
| `utils/` | Hàm tiện ích dùng chung |
| `main.dart` | Điểm khởi chạy ứng dụng, khởi tạo các phần cần thiết |
| `app.dart` | Cấu hình MaterialApp, routes và theme tổng |

------------------------------------------------------------------------

# 2. Phân chia nhiệm vụ cho nhóm 4 người (làm song song)

## Nguyên tắc để 4 người làm song song, không phải chờ nhau

1. Thống nhất trước cách các phần nói chuyện với nhau (đầu vào, đầu ra của từng chức năng).

2. Mỗi thành viên làm trên 1 nhánh riêng, hạn chế sửa cùng 1 file để tránh xung đột.

3. Tách rõ vai trò: UI chỉ hiển thị; Provider điều phối; Repository/Service xử lý dữ liệu.

4. Dùng mock test (kiểm thử bằng dữ liệu giả) ngay từ đầu để không cần chờ Firebase hoặc Gemini thật.

5. Chỉ merge khi qua kiểm tra cơ bản:

    flutter analyze
    flutter test

------------------------------------------------------------------------

## Thành viên 1 - UI / UX

**Trách nhiệm**

-   Xây dựng màn hình và các widget dùng lại nhiều nơi
-   Hoàn thiện các trạng thái giao diện: đăng nhập, đang tải, lỗi, không có dữ liệu
-   Không đặt xử lý nghiệp vụ trong màn hình

**Thư mục thao tác**

    lib/screens/
    lib/core/theme/
    lib/utils/
    lib/app.dart

**Kiểm thử bằng dữ liệu giả (mock test)**

-   Tạo dữ liệu giả để chạy thử giao diện ngay cả khi backend chưa xong
-   Khi Provider chưa hoàn thành, dùng Provider giả trả dữ liệu mẫu
-   Viết test giao diện cho các trạng thái chính (đang tải, thành công, lỗi)

------------------------------------------------------------------------

## Thành viên 2 - Backend / Firebase

**Trách nhiệm**

-   Xây dựng phần đọc/ghi dữ liệu với Firebase
-   Viết phần Repository cho Firestore và đăng nhập
-   Đổi lỗi kỹ thuật từ Firebase thành lỗi dễ hiểu cho app

**Thư mục thao tác**

    lib/services/firebase/
    lib/models/
    lib/repositories/

**Kiểm thử bằng dữ liệu giả (mock test)**

-   Viết test từng hàm nhỏ cho Service/Repository bằng dữ liệu giả
-   Tạo test cho cả 2 trường hợp: thành công và thất bại
-   Nếu cần kiểm tra gần giống môi trường thật, dùng Firebase Emulator (Firebase chạy cục bộ trên máy)

------------------------------------------------------------------------

## Thành viên 3 - AI Gemini

**Trách nhiệm**

-   Tích hợp Gemini và xử lý gửi câu hỏi/nhận câu trả lời
-   Xử lý các tình huống lỗi: mạng chậm, hết thời gian chờ, trả dữ liệu rỗng
-   Chuẩn bị sẵn bản Gemini giả để các phần khác test độc lập

**Thư mục thao tác**

    lib/services/ai/
    lib/repositories/

**Kiểm thử bằng dữ liệu giả (mock test)**

-   Tạo một Gemini giả (MockGeminiService) trả về câu trả lời cố định để thành viên khác dùng ngay
-   Viết test cho các trường hợp: hết thời gian chờ, dữ liệu sai định dạng, dữ liệu rỗng
-   Cung cấp bộ câu hỏi mẫu và kết quả mong muốn để test tự động

API key lưu trong:

    .env

------------------------------------------------------------------------

## Thành viên 4 - Logic / State và tích hợp

**Trách nhiệm**

-   Xây dựng Provider và các trạng thái chính
-   Nối UI với Repository/Service theo luồng dữ liệu đã thống nhất
-   Cấu hình Provider trong `main.dart` và đảm bảo app khởi động ổn định

**Thư mục thao tác**

    lib/providers/
    lib/main.dart

Ví dụ:

    providers/auth_provider.dart
    providers/chat_provider.dart

**Kiểm thử bằng dữ liệu giả (mock test)**

-   Viết test cho Provider với dữ liệu giả cho đăng nhập và chat (MockAuthRepository, MockChatRepository)
-   Chạy test theo luồng: đăng nhập -> tải dữ liệu -> xử lý lỗi (dùng dữ liệu giả)
-   Khi backend/AI thật sẵn sàng, chỉ thay phần dữ liệu giả bằng dữ liệu thật, UI giữ nguyên

------------------------------------------------------------------------

## Giải thích nhanh thuật ngữ

-   Mock test: Kiểm thử bằng dữ liệu giả để làm việc sớm, không phải chờ hệ thống thật
-   Provider: Nơi quản lý trạng thái để màn hình biết đang tải, thành công hay lỗi
-   Repository: Lớp trung gian lấy dữ liệu từ Service rồi trả về cho Provider
-   Service: Nơi gọi Firebase hoặc Gemini
-   Firebase Emulator: Bản Firebase chạy ngay trên máy cá nhân để test an toàn

------------------------------------------------------------------------

## Tách nhánh đề xuất để làm song song

    feature/member1-ui-ux
    feature/member2-firebase-data
    feature/member3-gemini-ai
    feature/member4-provider-integration

------------------------------------------------------------------------

# 3. File quan trọng

## main.dart

Trách nhiệm:

-   Khởi tạo Firebase
-   Nạp biến môi trường
-   Khai báo Provider để toàn app dùng chung
-   Khởi chạy ứng dụng

⚠️ Chỉ nhiệm vụ **Logic / State** nên chỉnh sửa file này.

------------------------------------------------------------------------

## app.dart

Trách nhiệm:

-   Cấu hình ứng dụng chính (`MaterialApp`)
-   Quản lý giao diện chung (theme)
-   Quản lý chuyển màn hình (routes)
-   Định nghĩa màn hình khởi đầu

⚠️ Chỉ nhiệm vụ **UI / UX** nên chỉnh sửa file này.

------------------------------------------------------------------------

# 4. Quy trình Git

## Bắt đầu công việc mỗi ngày (bắt buộc)

Để tránh lệch code giữa các thành viên, trước khi tạo nhánh mới hãy luôn làm đúng 3 bước sau:

1. Luôn chuyển về nhánh `develop`

    git checkout develop

2. Cập nhật code mới nhất từ server về máy (rất quan trọng)

    git pull origin develop

3. Tạo nhánh feature mới và chuyển sang nhánh đó

    git checkout -b feature/<tên-nhánh>

Ví dụ đặt tên nhánh dễ hiểu:

    feature/ui-login
    feature/firebase-user-profile
    feature/gemini-chat-box
    feature/provider-auth-flow

## Tạo nhánh tính năng

Ví dụ:

    feature/member1-ui-ux
    feature/member2-firebase-data
    feature/member3-gemini-ai
    feature/member4-provider-integration

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

    services/firebase/firestore_service.dart
    services/ai/gemini_service.dart
    services/firebase/auth_service.dart (nếu có)

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

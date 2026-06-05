# SHCare — Ứng dụng Chăm sóc Sức khỏe Thông minh

---

## 🔑 Tài khoản Mock Test

> Dùng để test giao diện. Khi tích hợp Firebase Auth thật sẽ thay thế.

| # | Email | Mật khẩu | Tên hiển thị | Vai trò |
|---|-------|----------|--------------|---------|
| 1 | `admin@shcare.vn` | `admin123` | Admin SHCare | Quản trị viên |
| 2 | `khang@shcare.vn` | `khang123` | Huỳnh Vĩnh Khang | Thành viên nhóm |
| 3 | `test@shcare.vn` | `test1234` | Tester SHCare | Kiểm thử |
| 4 | `demo@shcare.vn` | `demo1234` | Demo User | Demo trình bày |

- **Google / Facebook**: Nhấn nút → tự động đăng nhập thành công (mock).
- **Đăng ký**: Điền bất kỳ thông tin hợp lệ → tạo tài khoản thành công. Email trùng mock sẽ báo lỗi.

---

## 1. Cấu trúc dự án

```text
lib/
├── app.dart                     ← MaterialApp, routes, theme
├── main.dart                    ← Khởi tạo Firebase, Provider
├── core/
│   ├── config/firebase_options.dart
│   ├── constants/app_strings.dart
│   ├── providers/audio_provider.dart
│   ├── theme/
│   │   ├── app_colors.dart      ← Hệ thống màu thống nhất
│   │   └── app_theme.dart       ← Theme Material 3
│   └── widgets/gif_icon.dart
├── models/                      ← ⭐ DATA MODELS CHUNG
│   ├── user_model.dart          ← Thông tin người dùng
│   ├── diary_entry.dart         ← Nhật ký sức khỏe hàng ngày
│   ├── pet_model.dart           ← Trạng thái Pet AI
│   └── task_suggestion.dart     ← Gợi ý từ AI
├── repositories/                ← ⭐ REPOSITORY PATTERN
│   ├── health_repository.dart   ← Interface (abstract class)
│   └── mock_health_repository.dart ← Mock data cho dev/test
├── providers/
│   └── auth_provider.dart
├── features/
│   ├── auth/screens/            ← Đăng nhập / Đăng ký
│   ├── home/                    ← Trang chủ + Pet AI
│   ├── stats/                   ← Thống kê sức khỏe
│   ├── tips/                    ← Gợi ý thông minh
│   ├── journal/                 ← Nhật ký hàng ngày
│   └── main/screens/            ← BottomNav container
├── services/
│   ├── ai/gemini_service.dart
│   └── firebase/firestore_service.dart
└── utils/
    ├── date_formatter.dart
    └── rive_analyzer.dart
```

---

## 2. ⭐ Thống nhất Data Models (BẮT BUỘC ĐỌC)

**Trước khi code, cả team phải dùng chung 4 model đã định nghĩa sẵn trong `lib/models/`.**

### 2.1 UserModel (`models/user_model.dart`)

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| `id` | `String` | ID duy nhất |
| `email` | `String` | Email đăng nhập |
| `name` | `String` | Họ tên |
| `gender` | `String?` | `'male'` / `'female'` / `'other'` |
| `heightCm` | `double?` | Chiều cao (cm) |
| `weightKg` | `double?` | Cân nặng (kg) |
| `birthYear` | `int?` | Năm sinh |
| `stepGoal` | `int` | Mục tiêu bước/ngày (mặc định 10000) |
| `waterGoalLiters` | `double` | Mục tiêu nước/ngày (mặc định 2.0) |

### 2.2 DiaryEntry (`models/diary_entry.dart`)

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| `date` | `DateTime` | Ngày ghi nhật ký |
| `stepCount` | `int` | Số bước đi |
| `caloriesBurned` | `int` | Calo đốt |
| `waterIntakeLiters` | `double` | Lượng nước đã uống |
| `sleepMinutes` | `int` | Tổng phút ngủ |
| `deepSleepMinutes` | `int?` | Phút ngủ sâu |
| `heartRateBpm` | `int?` | Nhịp tim |
| `hrv` | `int?` | Heart Rate Variability |
| `moodIndex` | `int` | 0=Rất tốt, 1=Ổn, 2=BT, 3=Căng thẳng |
| `energyLevel` | `double` | 0.0 → 1.0 |
| `symptoms` | `List<String>` | Triệu chứng |
| `note` | `String?` | Ghi chú tự do |

### 2.3 PetModel (`models/pet_model.dart`)

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| `level` | `int` | Cấp độ Pet |
| `currentExp` | `int` | EXP hiện tại |
| `expToNextLevel` | `int` | EXP cần để lên cấp (100) |
| `state` | `String` | `'Năng động'` / `'Khát'` / `'Mệt mỏi'` |
| `message` | `String` | Tin nhắn Pet nói |
| `currentTask` | `String` | Nhiệm vụ Pet giao |

### 2.4 TaskSuggestion (`models/task_suggestion.dart`)

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| `title` | `String` | Tiêu đề gợi ý |
| `description` | `String` | Mô tả chi tiết |
| `category` | `String` | `'Dinh dưỡng'` / `'Vận động'` / `'Tinh thần'` / `'Ngủ'` |
| `duration` | `String` | Thời gian thực hiện |
| `priority` | `int` | 1=Cao, 2=Trung bình, 3=Thấp |
| `source` | `String?` | `'ai'` / `'rule_based'` |

> **⚠️ Quy tắc: Mọi thành viên KHÔNG được tự tạo model riêng. Nếu cần thêm trường, tạo PR và thảo luận với cả nhóm.**

---

## 3. ⭐ Repository Pattern — Cách dùng Mock Data

### 3.1 Nguyên lý

```
UI (Screen/Widget)
    ↓ gọi
Provider (State Management)
    ↓ gọi
HealthRepository (Interface)
    ↓ implement
MockHealthRepository  ← Đang dùng (dev/test)
FirebaseHealthRepository ← Sau khi tích hợp thật
```

### 3.2 Interface đã có sẵn: `repositories/health_repository.dart`

```dart
abstract class HealthRepository {
  Future<UserModel?> getCurrentUser();
  Future<void> updateUserProfile(UserModel user);
  Future<DiaryEntry?> getDiaryEntry(String userId, DateTime date);
  Future<List<DiaryEntry>> getDiaryHistory(String userId, {int days = 30});
  Future<void> saveDiaryEntry(DiaryEntry entry);
  Future<PetModel?> getPet(String userId);
  Future<void> updatePet(PetModel pet);
  Future<List<TaskSuggestion>> getTodaySuggestions(String userId);
  Future<void> saveSuggestions(List<TaskSuggestion> suggestions);
  Future<void> completeSuggestion(String suggestionId);
}
```

### 3.3 Mock đã có sẵn: `repositories/mock_health_repository.dart`

Đã bao gồm:
- `mockUser` — User với chiều cao 172cm, cân nặng 68.5kg, mục tiêu 10000 bước
- `mockHistory` — 30 ngày dữ liệu giả (có ngày tốt, ngày xấu)
- `mockPet` — Pet Level 3, EXP 45
- `mockSuggestions` — 3 gợi ý AI mẫu
- Tất cả hàm đều có `Future.delayed` mô phỏng delay mạng

### 3.4 Cách dùng trong Provider

```dart
class HealthProvider extends ChangeNotifier {
  // ✅ Dùng interface, KHÔNG dùng trực tiếp Firebase
  final HealthRepository _repo;

  HealthProvider({HealthRepository? repo})
      : _repo = repo ?? MockHealthRepository();

  Future<void> loadHistory() async {
    final history = await _repo.getDiaryHistory('mock_user_001');
    // Xử lý dữ liệu...
    notifyListeners();
  }
}
```

### 3.5 Khi chuyển sang Firebase thật

Chỉ cần tạo `FirebaseHealthRepository implements HealthRepository` rồi thay **1 dòng**:

```dart
// Trước (mock)
HealthProvider(repo: MockHealthRepository())

// Sau (thật)
HealthProvider(repo: FirebaseHealthRepository())
```

---

## 4. Phân chia nhiệm vụ — 4 thành viên

### Thành viên 1 — Auth & Trang cá nhân

**Trách nhiệm:**
- Hoàn thiện màn hình đăng nhập / đăng ký (đã có sẵn trong `features/auth/`)
- Xây dựng trang cá nhân (Profile) hiển thị & chỉnh sửa `UserModel`
- Xử lý luồng: chưa đăng nhập → Login → MainScreen

**Thư mục làm việc:**
```
lib/features/auth/
lib/providers/auth_provider.dart
```

**Cách dùng Mock:**
```dart
// Khi user nhấn "Đăng nhập", dùng Future.delayed mô phỏng 2s chờ mạng
// rồi cho qua MainScreen. Đã implement sẵn trong auth_provider.dart.
// Khi cần hiển thị Profile:
final user = await MockHealthRepository().getCurrentUser();
// → Trả về UserModel với đầy đủ chiều cao, cân nặng, mục tiêu
```

---

### Thành viên 2 — Trang chủ Pet & Thống kê

**Trách nhiệm:**
- Hoàn thiện Pet AI widget (animation, EXP bar, level up)
- Vẽ biểu đồ thống kê từ lịch sử `DiaryEntry`
- Logic cộng EXP cho Pet khi hoàn thành nhiệm vụ

**Thư mục làm việc:**
```
lib/features/home/widgets/ai_pet_widget.dart
lib/features/home/widgets/pet_aura_effect.dart
lib/features/stats/
lib/features/home/providers/health_provider.dart
```

**Cách dùng Mock:**
```dart
// KHÔNG cần chờ Thành viên 4 nhập dữ liệu
final repo = MockHealthRepository();

// Lấy 30 ngày lịch sử → vẽ biểu đồ
final history = await repo.getDiaryHistory('mock_user_001', days: 30);

// Lấy pet → hiển thị level, EXP
final pet = await repo.getPet('mock_user_001');

// Test logic EXP: hoàn thành task → cộng EXP → check lên cấp
final updatedPet = pet!.copyWith(
  currentExp: pet.currentExp + 20,
  level: (pet.currentExp + 20 >= 100) ? pet.level + 1 : pet.level,
);
await repo.updatePet(updatedPet);
```

---

### Thành viên 3 — Trang gợi ý AI (Gemini)

**Trách nhiệm:**
- Ghép `UserModel` + `DiaryEntry` thành prompt gửi lên Gemini API
- Xử lý response → tạo `List<TaskSuggestion>`
- Hiển thị gợi ý lên UI (`features/tips/`)

**Thư mục làm việc:**
```
lib/services/ai/gemini_service.dart
lib/features/tips/
lib/models/task_suggestion.dart
```

**Cách dùng Mock:**
```dart
// Lấy mockUser + mockHistory làm đầu vào cho prompt
final repo = MockHealthRepository();
final user = await repo.getCurrentUser();
final history = await repo.getDiaryHistory('mock_user_001', days: 7);

// Ghép thành prompt
final prompt = '''
Người dùng: ${user!.name}, ${user.heightCm}cm, ${user.weightKg}kg
7 ngày gần đây:
${history.map((d) => '- ${d.date.day}/${d.date.month}: ${d.stepCount} bước, ${d.waterIntakeLiters}L nước, mood=${d.moodIndex}').join('\n')}

Hãy đưa ra 3 gợi ý sức khỏe cá nhân hóa.
''';

// Gửi lên Gemini API → parse response → tạo List<TaskSuggestion>
```

**API Key:** Lưu trong file `.env`, truy cập qua `dotenv.env['GEMINI_API_KEY']`.

---

### Thành viên 4 — Nhật ký sức khỏe

**Trách nhiệm:**
- Hoàn thiện UI nhật ký (`features/journal/`)
- Xử lý luồng: chọn mood → nhập nước → ghi triệu chứng → lưu
- Khi nhấn "Lưu", tạo `DiaryEntry` và gọi `repo.saveDiaryEntry()`

**Thư mục làm việc:**
```
lib/features/journal/
```

**Cách dùng Mock:**
```dart
// Khi bấm "Lưu nhật ký" → tạo DiaryEntry → gọi mock save
final entry = DiaryEntry(
  id: 'diary_today',
  userId: 'mock_user_001',
  date: DateTime.now(),
  stepCount: 8500,
  waterIntakeLiters: 1.75,
  moodIndex: 1,
  energyLevel: 0.72,
  symptoms: ['Mỏi cổ vai'],
  note: 'Hôm nay cảm thấy ổn.',
);

final repo = MockHealthRepository();
await repo.saveDiaryEntry(entry);
// → Console sẽ in: [MOCK] Đã lưu nhật ký ngày: 2026-05-12

// Verify: Đọc lại để check UI cập nhật
final saved = await repo.getDiaryEntry('mock_user_001', DateTime.now());
```

---

## 5. Quy trình Git

### Bắt đầu mỗi ngày

```bash
git checkout develop
git pull origin develop
git checkout -b <tiền-tố>/<tên-nhánh>
```

### Tên nhánh đề xuất

```
feature/tv1-auth-profile
feature/tv2-pet-stats
feature/tv3-ai-tips
feature/tv4-journal
```

### Quy ước tiền tố

| Tiền tố | Khi nào dùng | Ví dụ |
|---------|-------------|-------|
| `feat/` | Tính năng mới | `feat/login-screen` |
| `fix/` | Sửa lỗi | `fix/null-user-data` |
| `chore/` | Cấu hình, bảo trì | `chore/update-deps` |
| `docs/` | Tài liệu | `docs/update-readme` |
| `refactor/` | Tối ưu code | `refactor/split-widgets` |

### Quy tắc commit

```
feat: add home screen UI
feat: implement gemini prompt builder
fix: null check on diary entry
docs: update mock data guide
```

### Trước khi merge

```bash
flutter analyze
flutter test
```

---

## 6. Quy chuẩn code

- Mỗi file giữ dưới ~300 dòng khi có thể
- Business logic ở `provider` hoặc `service`, KHÔNG ở UI
- **File/thư mục**: `snake_case` → `home_screen.dart`
- **Class/Enum**: `UpperCamelCase` → `class HomeScreen`
- **Biến/Hàm**: `lowerCamelCase` → `int heartRate`
- **Hằng số Dart**: `lowerCamelCase` → `const int maxRetries = 3`
- **Hằng số .env**: `SCREAMING_SNAKE_CASE` → `GEMINI_API_KEY`

### Hậu tố bắt buộc

| Vai trò | Hậu tố | Ví dụ |
|---------|--------|-------|
| Giao diện | `...Screen` / `...Widget` | `LoginScreen` |
| Quản lý trạng thái | `...Provider` | `AuthProvider` |
| Xử lý logic/API | `...Service` | `GeminiService` |
| Cấu trúc dữ liệu | `...Model` / (tên thực thể) | `UserModel`, `DiaryEntry` |
| Kho dữ liệu | `...Repository` | `HealthRepository` |

---

## 7. Kiến trúc tổng quan

```
UI Layer (screens/, widgets/)
    ↓
Provider (State Management)
    ↓
Repository (Interface)
    ↓
MockHealthRepository (dev)  ←→  FirebaseHealthRepository (production)
    ↓
Firebase / Gemini API
```

**Lợi ích:**
- 4 người làm song song, không chờ nhau
- Chuyển Mock → Firebase chỉ thay 1 dòng code
- Viết Unit Test dễ dàng với Mock
- UI hoàn toàn tách biệt khỏi nguồn dữ liệu

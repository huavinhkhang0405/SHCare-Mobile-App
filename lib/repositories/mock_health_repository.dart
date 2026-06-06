import 'dart:math';

import '../models/diary_entry.dart';
import '../models/pet_model.dart';
import '../models/task_suggestion.dart';
import '../models/user_model.dart';
import 'health_repository.dart';

/// Mock data giả lập dùng để phát triển & test offline.
///
/// Tất cả thành viên dùng class này thay cho Firebase thật.
/// Khi Firebase sẵn sàng, chỉ cần tạo [FirebaseHealthRepository]
/// rồi thay 1 dòng trong Provider/main.dart.
class MockHealthRepository implements HealthRepository {
  // ─── Dữ liệu giả cục bộ ──────────────────────────────────
  final _random = Random(42); // Seed cố định để kết quả ổn định

  late final UserModel _mockUser = UserModel(
    id: 'mock_user_001',
    email: 'admin@shcare.vn',
    name: 'Admin SHCare',
    avatarUrl: null,
    gender: 'male',
    heightCm: 172,
    weightKg: 68.5,
    birthYear: 2003,
    stepGoal: 10000,
    waterGoalLiters: 2.0,
  );

  late final PetModel _mockPet = PetModel(
    id: 'pet_001',
    userId: 'mock_user_001',
    name: 'SHCare Buddy',
    level: 3,
    currentExp: 45,
    state: 'Năng động',
    message: 'Bạn đang duy trì nhịp sinh hoạt rất tốt!',
    currentTask: 'Đi bộ thêm 500 bước trong 30 phút tới.',
  );

  /// 30 ngày dữ liệu giả — Thành viên 2 dùng để vẽ biểu đồ,
  /// Thành viên 3 dùng làm đầu vào cho AI prompt.
  late final List<DiaryEntry> _mockHistory = _generateMockHistory();

  final List<TaskSuggestion> _mockSuggestions = [
    TaskSuggestion(
      id: 'sug_001',
      userId: 'mock_user_001',
      title: 'Bổ sung nước ngay',
      description: 'Bạn còn thiếu 35% mục tiêu nước. Thêm 1 ly 250ml.',
      category: 'Dinh dưỡng',
      duration: '2 phút',
      priority: 1,
      source: 'ai',
    ),
    TaskSuggestion(
      id: 'sug_002',
      userId: 'mock_user_001',
      title: 'Đi bộ thêm 1500 bước',
      description: 'Bạn đã đạt 85% mục tiêu. Cố thêm chút nữa!',
      category: 'Vận động',
      duration: '15 phút',
      priority: 2,
      source: 'ai',
    ),
    TaskSuggestion(
      id: 'sug_003',
      userId: 'mock_user_001',
      title: 'Thở 4-7-8 trong 3 phút',
      description: 'Nhịp tim 82bpm. Bài thở chậm giúp hạ căng thẳng.',
      category: 'Tinh thần',
      duration: '3 phút',
      priority: 1,
      source: 'ai',
    ),
  ];

  // ─── Sinh dữ liệu 30 ngày ────────────────────────────────
  List<DiaryEntry> _generateMockHistory() {
    final today = DateTime.now();
    return List.generate(30, (i) {
      final date = today.subtract(Duration(days: i));
      final isGoodDay = _random.nextBool();
      
      final mockFoods = isGoodDay
          ? ['Phở bò', 'Nước cam', 'Cơm gà', 'Salad ức gà']
          : ['Bánh mì chả', 'Cà phê đá', 'Mì gói', 'Coca Cola'];
      final calories = isGoodDay
          ? 1800 + _random.nextInt(400)
          : 1200 + _random.nextInt(400);
      final protein = isGoodDay
          ? 80 + _random.nextInt(20)
          : 40 + _random.nextInt(20);
      final carbs = isGoodDay
          ? 200 + _random.nextInt(50)
          : 150 + _random.nextInt(50);
      final fat = isGoodDay
          ? 50 + _random.nextInt(15)
          : 40 + _random.nextInt(15);

      return DiaryEntry(
        id: 'diary_${30 - i}',
        userId: 'mock_user_001',
        date: date,
        stepCount: isGoodDay
            ? 8000 + _random.nextInt(4000)
            : 3000 + _random.nextInt(4000),
        caloriesBurned: 300 + _random.nextInt(400),
        waterIntakeLiters: isGoodDay
            ? 1.5 + _random.nextDouble() * 0.8
            : 0.5 + _random.nextDouble() * 0.8,
        sleepMinutes: 360 + _random.nextInt(120),
        deepSleepMinutes: 120 + _random.nextInt(80),
        // Nhịp tim nghỉ ngơi dao động quanh mức 68 - 72 bpm (mốc của User Admin Demo có BMI chuẩn)
        restingHeartRate: 68 + _random.nextInt(5), // 68 to 72
        // Nhịp tim hiện tại quanh mức nhịp tim nghỉ ngơi ±3 bpm
        heartRateBpm: 68 + _random.nextInt(5) + (_random.nextInt(7) - 3),
        hrv: 40 + _random.nextInt(25),
        moodIndex: isGoodDay ? _random.nextInt(2) : 2 + _random.nextInt(2),
        energyLevel: isGoodDay
            ? 0.6 + _random.nextDouble() * 0.35
            : 0.25 + _random.nextDouble() * 0.35,
        symptoms: isGoodDay
            ? ['Không có']
            : ['Mỏi cổ vai', 'Mất tập trung']
                .where((_) => _random.nextBool())
                .toList(),
        note: i == 0 ? 'Hôm nay cảm thấy tốt, đã tập thể dục sáng.' : null,
        consumedCalories: calories,
        consumedProtein: protein,
        consumedCarbs: carbs,
        consumedFat: fat,
        todayFoods: mockFoods,
      );
    });
  }

  // ─── Implement Interface ──────────────────────────────────

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockUser;
  }

  @override
  Future<void> updateUserProfile(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock: Chỉ log ra console, không lưu thật
    // ignore: avoid_print
    print('[MOCK] Đã cập nhật profile: ${user.name}');
  }

  @override
  Future<DiaryEntry?> getDiaryEntry(String userId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final dateStr = date.toIso8601String().substring(0, 10);
    try {
      return _mockHistory.firstWhere(
        (e) => e.date.toIso8601String().substring(0, 10) == dateStr,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DiaryEntry>> getDiaryHistory(
    String userId, {
    int days = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockHistory.take(days).toList();
  }

  @override
  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock: Log + thêm vào list local
    final index = _mockHistory.indexWhere(
      (e) =>
          e.date.toIso8601String().substring(0, 10) ==
          entry.date.toIso8601String().substring(0, 10),
    );
    if (index >= 0) {
      _mockHistory[index] = entry;
    } else {
      _mockHistory.insert(0, entry);
    }
    // ignore: avoid_print
    print('[MOCK] Đã lưu nhật ký ngày: ${entry.date.toIso8601String().substring(0, 10)}');
  }

  @override
  Future<PetModel?> getPet(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockPet;
  }

  @override
  Future<void> updatePet(PetModel pet) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('[MOCK] Pet cập nhật: Level ${pet.level}, EXP ${pet.currentExp}');
  }

  @override
  Future<List<TaskSuggestion>> getTodaySuggestions(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockSuggestions);
  }

  @override
  Future<void> saveSuggestions(List<TaskSuggestion> suggestions) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print('[MOCK] Đã lưu ${suggestions.length} gợi ý AI');
  }

  @override
  Future<void> completeSuggestion(String suggestionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockSuggestions.indexWhere((s) => s.id == suggestionId);
    if (index >= 0) {
      _mockSuggestions[index] =
          _mockSuggestions[index].copyWith(isCompleted: true);
    }
    // ignore: avoid_print
    print('[MOCK] Đã hoàn thành gợi ý: $suggestionId');
  }
}

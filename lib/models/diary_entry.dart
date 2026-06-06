/// Mô hình nhật ký sức khỏe hàng ngày.
///
/// Mỗi ngày người dùng có tối đa 1 bản ghi DiaryEntry.
/// Thành viên 4 (Nhật ký) tạo dữ liệu, Thành viên 2 (Pet/Stats) đọc lịch sử,
/// Thành viên 3 (AI) dùng làm đầu vào cho prompt.
class DiaryEntry {
  final String id;
  final String userId;
  final DateTime date;

  // ─── Chỉ số vận động ─────────────────────────────────────
  final int stepCount;
  final int caloriesBurned;

  // ─── Nước uống ────────────────────────────────────────────
  final double waterIntakeLiters;

  // ─── Giấc ngủ ─────────────────────────────────────────────
  final int sleepMinutes; // Tổng phút ngủ
  final int? deepSleepMinutes; // Phút ngủ sâu

  // ─── Nhịp tim ─────────────────────────────────────────────
  final int? heartRateBpm;
  final int? restingHeartRate;
  final int? hrv; // Heart Rate Variability (ms)

  // ─── Tâm trạng & Năng lượng ───────────────────────────────
  /// 0 = Rất tốt, 1 = Ổn định, 2 = Bình thường, 3 = Căng thẳng
  final int moodIndex;
  final double energyLevel; // 0.0 → 1.0

  // ─── Triệu chứng & Ghi chú ───────────────────────────────
  final List<String> symptoms;
  final String? note;

  // ─── Dinh dưỡng ───────────────────────────────────────────
  final int consumedCalories;
  final int consumedProtein;
  final int consumedCarbs;
  final int consumedFat;
  final List<String> todayFoods;

  // ─── Metadata ─────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime? updatedAt;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.stepCount = 0,
    this.caloriesBurned = 0,
    this.waterIntakeLiters = 0.0,
    this.sleepMinutes = 0,
    this.deepSleepMinutes,
    this.heartRateBpm,
    this.restingHeartRate,
    this.hrv,
    this.moodIndex = 1,
    this.energyLevel = 0.5,
    this.symptoms = const [],
    this.note,
    this.consumedCalories = 0,
    this.consumedProtein = 0,
    this.consumedCarbs = 0,
    this.consumedFat = 0,
    this.todayFoods = const [],
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      stepCount: (json['step_count'] as int?) ?? 0,
      caloriesBurned: (json['calories_burned'] as int?) ?? 0,
      waterIntakeLiters:
          (json['water_intake_liters'] as num?)?.toDouble() ?? 0.0,
      sleepMinutes: (json['sleep_minutes'] as int?) ?? 0,
      deepSleepMinutes: json['deep_sleep_minutes'] as int?,
      heartRateBpm: json['heart_rate_bpm'] as int?,
      restingHeartRate: json['resting_heart_rate'] as int?,
      hrv: json['hrv'] as int?,
      moodIndex: (json['mood_index'] as int?) ?? 1,
      energyLevel: (json['energy_level'] as num?)?.toDouble() ?? 0.5,
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      note: json['note'] as String?,
      consumedCalories: (json['consumed_calories'] as int?) ?? 0,
      consumedProtein: (json['consumed_protein'] as int?) ?? 0,
      consumedCarbs: (json['consumed_carbs'] as int?) ?? 0,
      consumedFat: (json['consumed_fat'] as int?) ?? 0,
      todayFoods: (json['today_foods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().substring(0, 10), // chỉ lấy YYYY-MM-DD
      'step_count': stepCount,
      'calories_burned': caloriesBurned,
      'water_intake_liters': waterIntakeLiters,
      'sleep_minutes': sleepMinutes,
      'deep_sleep_minutes': deepSleepMinutes,
      'heart_rate_bpm': heartRateBpm,
      'resting_heart_rate': restingHeartRate,
      'hrv': hrv,
      'mood_index': moodIndex,
      'energy_level': energyLevel,
      'symptoms': symptoms,
      'note': note,
      'consumed_calories': consumedCalories,
      'consumed_protein': consumedProtein,
      'consumed_carbs': consumedCarbs,
      'consumed_fat': consumedFat,
      'today_foods': todayFoods,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DiaryEntry copyWith({
    int? stepCount,
    int? caloriesBurned,
    double? waterIntakeLiters,
    int? sleepMinutes,
    int? deepSleepMinutes,
    int? heartRateBpm,
    int? restingHeartRate,
    int? hrv,
    int? moodIndex,
    double? energyLevel,
    List<String>? symptoms,
    String? note,
    int? consumedCalories,
    int? consumedProtein,
    int? consumedCarbs,
    int? consumedFat,
    List<String>? todayFoods,
  }) {
    return DiaryEntry(
      id: id,
      userId: userId,
      date: date,
      stepCount: stepCount ?? this.stepCount,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      waterIntakeLiters: waterIntakeLiters ?? this.waterIntakeLiters,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrv: hrv ?? this.hrv,
      moodIndex: moodIndex ?? this.moodIndex,
      energyLevel: energyLevel ?? this.energyLevel,
      symptoms: symptoms ?? this.symptoms,
      note: note ?? this.note,
      consumedCalories: consumedCalories ?? this.consumedCalories,
      consumedProtein: consumedProtein ?? this.consumedProtein,
      consumedCarbs: consumedCarbs ?? this.consumedCarbs,
      consumedFat: consumedFat ?? this.consumedFat,
      todayFoods: todayFoods ?? this.todayFoods,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

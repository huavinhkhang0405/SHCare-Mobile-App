import 'package:cloud_firestore/cloud_firestore.dart';

class PetModel {
  final String id;
  final String userId;
  final String name;
  final int classType; // Tộc hệ / Class của Pet (1: Chiến binh, 2: Cung thủ, etc.)

  // ─── Level & EXP ──────────────────────────────────────────
  final int level;
  final int currentExp;
  final int expToNextLevel;

  // ─── Gamification AI ──────────────────────────────────────
  final int streakCount;
  final int streakFreezeCount;
  final int goldCoins;
  final DateTime? lastStreakUpdateDate;

  // ─── Trạng thái hiện tại ──────────────────────────────────
  /// Ví dụ: 'Năng động', 'Khát', 'Mệt mỏi', 'Vui vẻ'
  final String state;

  /// Tin nhắn Pet nói với người dùng (do AI hoặc rule-based tạo)
  final String message;

  /// Nhiệm vụ Pet giao cho người dùng
  final String currentTask;
  final bool isTaskCompleted;

  final String currentTitle; // Danh hiệu Gen Z hiện tại
  final String ownerName; // Tên chủ Pet (để flex trên Leaderboard)

  // ─── Metadata ─────────────────────────────────────────────
  final DateTime lastInteraction;

  PetModel({
    required this.id,
    required this.userId,
    this.name = 'SHCare Pet',
    int? classType,
    this.level = 1,
    this.currentExp = 0,
    this.expToNextLevel = 100,
    this.streakCount = 0,
    this.streakFreezeCount = 0,
    this.goldCoins = 0,
    this.lastStreakUpdateDate,
    this.state = 'Năng động',
    this.message = 'Chào bạn! Hôm nay mình cùng nhau rèn sức khỏe nhé.',
    this.currentTask = 'Đi bộ 500 bước để khởi động ngày mới.',
    this.isTaskCompleted = false,
    this.currentTitle = 'Chúa tể ôm giường',
    this.ownerName = 'Bạn của Pet',
    DateTime? lastInteraction,
  }) : lastInteraction = lastInteraction ?? DateTime.now(),
       classType = classType ?? getDefaultClass(userId);

  double get expProgress => currentExp / expToNextLevel;

  static int getDefaultClass(String userId) {
    if (userId.contains('admin')) {
      return 5;
    } else if (userId.contains('khang')) {
      return 4;
    } else if (userId.contains('test')) {
      return 3;
    } else if (userId.contains('demo')) {
      return 8;
    } else if (userId.isNotEmpty && userId != 'temp') {
      final hash = userId.codeUnits.fold<int>(0, (prev, element) => prev + element);
      return (hash % 8) + 1;
    }
    return 4; // default fallback if userId is empty or temp
  }

  factory PetModel.fromJson(Map<String, dynamic> json) {
    final userIdVal = json['user_id'] as String? ?? '';
    return PetModel(
      id: json['id'] as String,
      userId: userIdVal,
      name: (json['name'] as String?) ?? 'SHCare Pet',
      classType: json['class_type'] as int?,
      level: (json['level'] as int?) ?? 1,
      currentExp: (json['current_exp'] as int?) ?? 0,
      expToNextLevel: (json['exp_to_next_level'] as int?) ?? 100,
      streakCount: (json['streak_count'] as int?) ?? 0,
      streakFreezeCount: (json['streak_freeze_count'] as int?) ?? 0,
      goldCoins: (json['gold_coins'] as int?) ?? 0,
      lastStreakUpdateDate: json['last_streak_update_date'] != null
          ? DateTime.tryParse(json['last_streak_update_date'] as String)
          : null,
      state: (json['state'] as String?) ?? 'Năng động',
      message: (json['message'] as String?) ?? '',
      currentTask: (json['current_task'] as String?) ?? '',
      isTaskCompleted: (json['is_task_completed'] as bool?) ?? false,
      currentTitle: (json['current_title'] as String?) ?? 'Chúa tể ôm giường',
      ownerName: (json['owner_name'] as String?) ?? 'Bạn của Pet',
      lastInteraction: json['last_interaction'] != null
          ? DateTime.parse(json['last_interaction'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'class_type': classType,
      'level': level,
      'current_exp': currentExp,
      'exp_to_next_level': expToNextLevel,
      'streak_count': streakCount,
      'streak_freeze_count': streakFreezeCount,
      'gold_coins': goldCoins,
      'last_streak_update_date': lastStreakUpdateDate?.toIso8601String(),
      'state': state,
      'message': message,
      'current_task': currentTask,
      'is_task_completed': isTaskCompleted,
      'current_title': currentTitle,
      'owner_name': ownerName,
      'last_interaction': lastInteraction.toIso8601String(),
    };
  }

  PetModel copyWith({
    String? name,
    int? classType,
    int? level,
    int? currentExp,
    int? expToNextLevel,
    int? streakCount,
    int? streakFreezeCount,
    int? goldCoins,
    DateTime? lastStreakUpdateDate,
    String? state,
    String? message,
    String? currentTask,
    bool? isTaskCompleted,
    String? currentTitle,
    String? ownerName,
  }) {
    return PetModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      classType: classType ?? this.classType,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      expToNextLevel: expToNextLevel ?? this.expToNextLevel,
      streakCount: streakCount ?? this.streakCount,
      streakFreezeCount: streakFreezeCount ?? this.streakFreezeCount,
      goldCoins: goldCoins ?? this.goldCoins,
      lastStreakUpdateDate: lastStreakUpdateDate ?? this.lastStreakUpdateDate,
      state: state ?? this.state,
      message: message ?? this.message,
      currentTask: currentTask ?? this.currentTask,
      isTaskCompleted: isTaskCompleted ?? this.isTaskCompleted,
      currentTitle: currentTitle ?? this.currentTitle,
      ownerName: ownerName ?? this.ownerName,
      lastInteraction: DateTime.now(),
    );
  }

  factory PetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return PetModel(id: doc.id, userId: '');
    }
    // Parse the userId from the parent reference path if available, to guarantee correct matching even if the Firestore fields are empty/historical
    final docUserId = doc.reference.parent.parent?.id ?? '';
    final userId = docUserId.isNotEmpty ? docUserId : ((data['user_id'] as String?) ?? '');
    int defaultClass = getDefaultClass(userId);

    // Enforce correct classes for mock accounts to override historical 'class_type: 4' values in Firestore
    int classTypeVal = (data['class_type'] as int?) ?? defaultClass;
    if (userId.contains('admin')) {
      classTypeVal = 5;
    } else if (userId.contains('khang')) {
      classTypeVal = 4;
    } else if (userId.contains('test')) {
      classTypeVal = 3;
    } else if (userId.contains('demo')) {
      classTypeVal = 8;
    }

    return PetModel(
      id: doc.id,
      userId: userId,
      name: (data['name'] as String?) ?? 'SHCare Pet',
      classType: classTypeVal,
      level: (data['level'] as int?) ?? 1,
      currentExp: (data['current_exp'] as int?) ?? 0,
      expToNextLevel: (data['exp_to_next_level'] as int?) ?? 100,
      streakCount: (data['streak_count'] as int?) ?? 0,
      streakFreezeCount: (data['streak_freeze_count'] as int?) ?? 0,
      goldCoins: (data['gold_coins'] as int?) ?? 0,
      lastStreakUpdateDate: data['last_streak_update_date'] != null
          ? DateTime.tryParse(data['last_streak_update_date'] as String)
          : null,
      state: (data['state'] as String?) ?? 'Năng động',
      message: (data['message'] as String?) ?? '',
      currentTask: (data['current_task'] as String?) ?? '',
      isTaskCompleted: (data['is_task_completed'] as bool?) ?? false,
      currentTitle: (data['current_title'] as String?) ?? 'Chúa tể ôm giường',
      ownerName: (data['owner_name'] as String?) ?? 'Bạn của Pet',
      lastInteraction: data['last_interaction'] != null
          ? DateTime.tryParse(data['last_interaction'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

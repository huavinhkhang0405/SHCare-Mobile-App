/// Mô hình gợi ý sức khỏe từ AI.
///
/// Thành viên 3 (AI) tạo danh sách gợi ý dựa trên DiaryEntry + UserModel,
/// Thành viên 2 (Tips UI) hiển thị lên giao diện.
class TaskSuggestion {
  final String id;
  final String userId;

  // ─── Nội dung gợi ý ──────────────────────────────────────
  final String title;
  final String description;
  final String category; // 'Dinh dưỡng' | 'Vận động' | 'Tinh thần' | 'Ngủ'
  final String duration; // Ví dụ: '5 phút', '10 phút'
  final int priority; // 1 = cao nhất, 3 = thấp nhất

  // ─── AI Integration Fields ────────────────────────────────
  /// EXP thưởng khi hoàn thành nhiệm vụ (do AI gán)
  final int expReward; // Dễ: 20, Vừa: 30, Khó: 50
  /// Loại nhiệm vụ gốc từ AI: 'water', 'exercise', 'rest', 'general'
  final String type;

  // ─── Trạng thái ───────────────────────────────────────────
  final bool isCompleted;
  final bool isDismissed;

  // ─── Metadata ─────────────────────────────────────────────
  final DateTime createdAt;
  final String? source; // 'ai' | 'rule_based' | 'manual'

  TaskSuggestion({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.category = 'Vận động',
    this.duration = '5 phút',
    this.priority = 2,
    this.expReward = 20,
    this.type = 'general',
    this.isCompleted = false,
    this.isDismissed = false,
    DateTime? createdAt,
    this.source = 'rule_based',
  }) : createdAt = createdAt ?? DateTime.now();

  // ─── Mapping type AI → category tiếng Việt ────────────────
  static const Map<String, String> _typeToCategoryMap = {
    'water': 'Dinh dưỡng',
    'exercise': 'Vận động',
    'rest': 'Tinh thần',
    'sleep': 'Ngủ',
    'general': 'Vận động',
  };

  /// Parse từ Firestore / format cũ
  factory TaskSuggestion.fromJson(Map<String, dynamic> json) {
    return TaskSuggestion(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: (json['category'] as String?) ?? 'Vận động',
      duration: (json['duration'] as String?) ?? '5 phút',
      priority: (json['priority'] as int?) ?? 2,
      expReward: (json['exp_reward'] as int?) ?? 20,
      type: (json['type'] as String?) ?? 'general',
      isCompleted: (json['is_completed'] as bool?) ?? false,
      isDismissed: (json['is_dismissed'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      source: json['source'] as String?,
    );
  }

  /// Parse từ response AI Gemini (format: task_name, exp_reward, type)
  /// Tự động map type → category tiếng Việt, và sinh id duy nhất.
  factory TaskSuggestion.fromAiJson(Map<String, dynamic> json, {String userId = 'mock_user_001'}) {
    final aiType = (json['type'] as String?) ?? 'general';
    final category = _typeToCategoryMap[aiType] ?? 'Vận động';
    final expReward = (json['exp_reward'] as int?) ?? 20;

    return TaskSuggestion(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${json.hashCode}',
      userId: userId,
      title: (json['task_name'] as String?) ?? 'Nhiệm vụ ẩn',
      description: (json['description'] as String?) ?? '',
      category: category,
      expReward: expReward,
      type: aiType,
      priority: expReward >= 50 ? 1 : (expReward >= 30 ? 2 : 3),
      source: 'ai',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'duration': duration,
      'priority': priority,
      'exp_reward': expReward,
      'type': type,
      'is_completed': isCompleted,
      'is_dismissed': isDismissed,
      'created_at': createdAt.toIso8601String(),
      'source': source,
    };
  }

  TaskSuggestion copyWith({
    bool? isCompleted,
    bool? isDismissed,
  }) {
    return TaskSuggestion(
      id: id,
      userId: userId,
      title: title,
      description: description,
      category: category,
      duration: duration,
      priority: priority,
      expReward: expReward,
      type: type,
      isCompleted: isCompleted ?? this.isCompleted,
      isDismissed: isDismissed ?? this.isDismissed,
      createdAt: createdAt,
      source: source,
    );
  }
}

/// Mô hình gợi ý sức khỏe từ AI.
class TaskSuggestion {
  final String id;
  final String taskName;
  final String description;
  final int expReward;
  final String type;
  final bool requiresImage;
  final bool isFlashQuest;
  final DateTime? expiresAt;
  final bool isCompleted;

  // Compatibility getter to prevent breaking UI references
  String get title => taskName;

  // Type-to-category mapping for backward compatibility
  static const Map<String, String> _typeToCategoryMap = {
    'water': 'Dinh dưỡng',
    'exercise': 'Vận động',
    'rest': 'Tinh thần',
    'sleep': 'Ngủ',
    'general': 'Vận động',
  };

  String get category => _typeToCategoryMap[type] ?? 'Vận động';
  String get duration => '5 phút';
  int get priority => expReward >= 50 ? 1 : (expReward >= 30 ? 2 : 3);

  TaskSuggestion({
    required this.id,
    String taskName = '',
    required this.description,
    this.expReward = 20,
    this.type = 'general',
    this.requiresImage = false,
    this.isFlashQuest = false,
    this.expiresAt,
    this.isCompleted = false,
    // Compatibility fields to prevent compile issues on mock data instantiations
    String? title,
    String? userId,
    String? category,
    String? duration,
    int? priority,
    String? source,
  }) : taskName = taskName.isNotEmpty ? taskName : (title ?? '');

  // Ép dữ liệu từ luồng lưu trữ SharedPreferences (Lưu mốc thời gian tuyệt đối)
  factory TaskSuggestion.fromJson(Map<String, dynamic> json) {
    return TaskSuggestion(
      id: json['id'] ?? '',
      taskName: json['task_name'] ?? json['title'] ?? '', // Support historical fallback
      description: json['description'] ?? '',
      expReward: json['exp_reward'] ?? 0,
      type: json['type'] ?? '',
      requiresImage: json['requires_image'] ?? false,
      isFlashQuest: json['is_flash_quest'] ?? false,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      isCompleted: json['is_completed'] ?? false,
    );
  }

  // Ép dữ liệu gốc sinh ra lần đầu tiên từ Gemini API
  factory TaskSuggestion.fromAiJson(Map<String, dynamic> json, String generatedId) {
    int? minutes = json['expires_in_minutes'] != null ?
        int.tryParse(json['expires_in_minutes'].toString()) : null;

    return TaskSuggestion(
      id: generatedId,
      taskName: json['task_name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      expReward: json['exp_reward'] ?? 0,
      type: json['type'] ?? '',
      requiresImage: json['requires_image'] is bool 
          ? json['requires_image'] 
          : (json['requires_image']?.toString().toLowerCase() == 'true'),
      isFlashQuest: json['is_flash_quest'] is bool 
          ? json['is_flash_quest'] 
          : (json['is_flash_quest']?.toString().toLowerCase() == 'true'),
      expiresAt: minutes != null ? DateTime.now().add(Duration(minutes: minutes)) : null,
      isCompleted: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_name': taskName,
      'description': description,
      'exp_reward': expReward,
      'type': type,
      'requires_image': requiresImage,
      'is_flash_quest': isFlashQuest,
      'expires_at': expiresAt?.toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  TaskSuggestion copyWith({
    String? id,
    String? taskName,
    String? description,
    int? expReward,
    String? type,
    bool? requiresImage,
    bool? isFlashQuest,
    DateTime? expiresAt,
    bool? isCompleted,
  }) {
    return TaskSuggestion(
      id: id ?? this.id,
      taskName: taskName ?? this.taskName,
      description: description ?? this.description,
      expReward: expReward ?? this.expReward,
      type: type ?? this.type,
      requiresImage: requiresImage ?? this.requiresImage,
      isFlashQuest: isFlashQuest ?? this.isFlashQuest,
      expiresAt: expiresAt ?? this.expiresAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

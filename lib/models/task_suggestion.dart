/// Mô hình gợi ý sức khỏe từ AI.
class TaskSuggestion {
  final String id;
  final String taskName;
  final String description;
  final int expReward;
  final String type;
  bool get requiresImage => !['exercise', 'sleep', 'rest', 'screen_free'].contains(type);
  final bool isFlashQuest;
  final DateTime? expiresAt;
  final bool isCompleted;

  // Trạng thái chống gian lận (Anti-Cheat State)
  final bool isAccepted;
  final DateTime? acceptedAt;
  final int startSteps;
  final double startWater;
  final int targetSteps;
  final Duration requiredDuration;

  // Validation getters
  bool get hasTargetStepsValidation => targetSteps > 0;
  bool get hasRequiredDurationValidation => requiredDuration.inMinutes > 0;

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
    this.isFlashQuest = false,
    this.expiresAt,
    this.isCompleted = false,
    this.isAccepted = false,
    this.acceptedAt,
    this.startSteps = 0,
    this.startWater = 0.0,
    this.targetSteps = 0,
    this.requiredDuration = Duration.zero,
    // Compatibility fields to prevent compile issues on mock data instantiations
    String? title,
    String? userId,
    String? category,
    String? duration,
    int? priority,
    String? source,
  }) : taskName = taskName.isNotEmpty ? taskName : (title ?? '');

  /// Helper an toàn: parse giá trị dynamic thành int, chống crash khi AI trả sai kiểu dữ liệu.
  static int _safeParseInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Helper bóc tách số từ chuỗi mô tả (description) dựa trên pattern (Regex).
  static int _parseValueFromDescription(String description, String pattern, {int fallback = 0}) {
    if (description.isEmpty) return fallback;
    try {
      final regExp = RegExp(pattern, caseSensitive: false);
      final match = regExp.firstMatch(description);
      if (match != null && match.groupCount >= 1) {
        // Loại bỏ các ký tự không phải số (ví dụ dấu phẩy, chấm trong 1.000)
        final valueStr = match.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
        if (valueStr != null && valueStr.isNotEmpty) {
          return int.parse(valueStr);
        }
      }
    } catch (e) {
      // Ignored, fallback below
    }
    return fallback;
  }

  // Ép dữ liệu từ luồng lưu trữ SharedPreferences (Lưu mốc thời gian tuyệt đối)
  factory TaskSuggestion.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['required_duration_minutes'] ?? json['requiredDurationMinutes'];
    return TaskSuggestion(
      id: json['id'] ?? '',
      taskName: json['task_name'] ?? json['title'] ?? '', // Support historical fallback
      description: json['description'] ?? '',
      expReward: _safeParseInt(json['exp_reward']),
      type: json['type'] ?? '',
      isFlashQuest: json['is_flash_quest'] ?? false,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      isCompleted: json['is_completed'] ?? false,
      isAccepted: json['is_accepted'] ?? false,
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'].toString()) : null,
      startSteps: _safeParseInt(json['start_steps']),
      startWater: (json['start_water'] as num?)?.toDouble() ?? 0.0,
      targetSteps: _safeParseInt(json['target_steps'] ?? json['targetSteps']),
      requiredDuration: rawDuration != null
          ? Duration(minutes: _safeParseInt(rawDuration))
          : Duration.zero,
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
      expReward: _safeParseInt(json['exp_reward']),
      type: json['type'] ?? '',
      isFlashQuest: json['is_flash_quest'] is bool 
          ? json['is_flash_quest'] 
          : (json['is_flash_quest']?.toString().toLowerCase() == 'true'),
      expiresAt: minutes != null ? DateTime.now().add(Duration(minutes: minutes)) : null,
      isCompleted: false,
      isAccepted: false,
      acceptedAt: null,
      startSteps: 0,
      startWater: 0.0,
      targetSteps: _safeParseInt(json['target_steps'], 
          _parseValueFromDescription(json['description'] ?? '', r'(\d+[\.\,]?\d*)\s*(?:bước|steps)')),
      requiredDuration: json['required_duration_minutes'] != null 
          ? Duration(minutes: _safeParseInt(json['required_duration_minutes'])) 
          : Duration(minutes: _parseValueFromDescription(json['description'] ?? '', r'(\d+)\s*(?:phút|minutes|mins)')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_name': taskName,
      'description': description,
      'exp_reward': expReward,
      'type': type,
      'is_flash_quest': isFlashQuest,
      'expires_at': expiresAt?.toIso8601String(),
      'is_completed': isCompleted,
      'is_accepted': isAccepted,
      'accepted_at': acceptedAt?.toIso8601String(),
      'start_steps': startSteps,
      'start_water': startWater,
      'target_steps': targetSteps,
      'required_duration_minutes': requiredDuration.inMinutes,
    };
  }

  TaskSuggestion copyWith({
    String? id,
    String? taskName,
    String? description,
    int? expReward,
    String? type,
    bool? isFlashQuest,
    DateTime? expiresAt,
    bool? isCompleted,
    bool? isAccepted,
    DateTime? acceptedAt,
    int? startSteps,
    double? startWater,
    int? targetSteps,
    Duration? requiredDuration,
  }) {
    return TaskSuggestion(
      id: id ?? this.id,
      taskName: taskName ?? this.taskName,
      description: description ?? this.description,
      expReward: expReward ?? this.expReward,
      type: type ?? this.type,
      isFlashQuest: isFlashQuest ?? this.isFlashQuest,
      expiresAt: expiresAt ?? this.expiresAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isAccepted: isAccepted ?? this.isAccepted,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startSteps: startSteps ?? this.startSteps,
      startWater: startWater ?? this.startWater,
      targetSteps: targetSteps ?? this.targetSteps,
      requiredDuration: requiredDuration ?? this.requiredDuration,
    );
  }
}
